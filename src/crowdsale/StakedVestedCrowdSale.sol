// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

import { VestedCrowdSale, VestingConfig, IncompatibleVestingContract, UnmanageableVestingContract } from "./VestedCrowdSale.sol";
import { CrowdSale, Sale, BadDecimals, SaleState } from "./CrowdSale.sol";

struct StakingConfig {
    //e.g. VITA DAO token
    IERC20Metadata stakedToken;
    TokenVesting stakesVestingContract;
    //fix price (always expressed at 1e18): stake tokens / bid token
    //see https://github.com/moleculeprotocol/IPNFT/pull/100
    uint256 wadFixedStakedPerBidPrice;
    //will be overridden with 0 during initialization
    uint256 stakeTotal;
}

error BadPrice();

/**
 * @title StakedVestedCrowdSale
 * @author molecule.to
 * @notice a fixed price sales base contract that locks the sold tokens in a configured vesting scheme and requires lock-vesting another ("dao") token for a certain period of time to participate
 */
contract StakedVestedCrowdSale is VestedCrowdSale {
    using SafeERC20 for IERC20Metadata;

    mapping(uint256 => StakingConfig) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) internal stakes;

    event Started(uint256 saleId, address indexed issuer, Sale sale, VestingConfig vesting, StakingConfig staking);
    event Staked(uint256 indexed saleId, address indexed bidder, uint256 stakedAmount, uint256 price);

    /**
     * @notice if vestingConfig.vestingContract is 0x0, a new vesting contract is automatically created
     *
     * @param sale sale configuration
     * @param stakingConfig staking config (provide 0 for stakingConfig.stakeTotal)
     * @param vestingConfig vesting config (will apply for both staked & auction tokens)
     */
    function startSale(Sale memory sale, StakingConfig memory stakingConfig, VestingConfig memory vestingConfig) public returns (uint256 saleId) {
        if (IERC20Metadata(address(stakingConfig.stakedToken)).decimals() != 18) {
            revert BadDecimals();
        }

        if (!stakingConfig.stakesVestingContract.hasRole(stakingConfig.stakesVestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
            revert UnmanageableVestingContract();
        }

        if (address(stakingConfig.stakesVestingContract.nativeToken()) != address(stakingConfig.stakedToken)) {
            revert IncompatibleVestingContract();
        }

        if (stakingConfig.wadFixedStakedPerBidPrice == 0) {
            revert BadPrice();
        }

        //if the bidding token (eg USDC) does not come with 18 decimals, we're adjusting the price here.
        //see https://github.com/moleculeprotocol/IPNFT/pull/100
        if (sale.biddingToken.decimals() != 18) {
            stakingConfig.wadFixedStakedPerBidPrice =
                (FP.divWadDown(FP.mulWadDown(stakingConfig.wadFixedStakedPerBidPrice, 10 ** 18), 10 ** sale.biddingToken.decimals()));
        }

        //todo: duck type check whether all token contracts can do what we need so users cannot create a sale with "bad" values
        stakingConfig.stakeTotal = 0;

        saleId = uint256(keccak256(abi.encode(sale)));
        salesStaking[saleId] = stakingConfig;
        super.startSale(sale, vestingConfig);
    }
    /**
     * @return uint256 how many stakingTokens `bidder` has staked into sale `saleId`
     */

    function stakesOf(uint256 saleId, address bidder) public view returns (uint256) {
        return stakes[saleId][bidder];
    }

    /**
     * @dev emits a custom event for this crowdsale class
     */
    function _afterSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId], salesStaking[saleId]);
    }

    /**
     * @dev calculates the amount of required staking tokens using the provided fix price
     *      will revert if bidder hasn't approved / owns a sufficient amount of staking tokens
     */
    function _bid(uint256 saleId, uint256 biddingTokenAmount) internal virtual override {
        StakingConfig storage staking = salesStaking[saleId];

        uint256 stakedTokenAmount = FP.mulWadDown(biddingTokenAmount, staking.wadFixedStakedPerBidPrice);

        staking.stakeTotal += stakedTokenAmount;
        stakes[saleId][msg.sender] += stakedTokenAmount;

        staking.stakedToken.safeTransferFrom(msg.sender, address(this), stakedTokenAmount);

        super._bid(saleId, biddingTokenAmount);
        emit Staked(saleId, msg.sender, stakedTokenAmount, staking.wadFixedStakedPerBidPrice);
    }

    /**
     * @notice refunds stakes and locks active stakes in vesting contract
     * @dev super.claim transitively calls VestedCrowdSale:_claimAuctionTokens
     * @inheritdoc CrowdSale
     */
    function claim(uint256 saleId, uint256 tokenAmount, uint256 refunds) internal virtual override {
        VestingConfig memory vestingConfig = salesVesting[saleId];
        StakingConfig memory stakingConfig = salesStaking[saleId];

        uint256 refundedStakes = FP.mulWadDown(refunds, stakingConfig.wadFixedStakedPerBidPrice);
        uint256 vestedStakes = stakes[saleId][msg.sender] - refundedStakes;

        if (vestedStakes == 0) {
            //exit early. Also, the vesting contract would revert with a 0 amount.
            return;
        }

        //EFFECTS
        //this prevents msg.sender to claim twice
        stakes[saleId][msg.sender] = 0;

        // INTERACTIONS
        super.claim(saleId, tokenAmount, refunds);

        if (refundedStakes > 0) {
            stakingConfig.stakedToken.safeTransfer(msg.sender, refundedStakes);
        }

        if (block.timestamp > _sales[saleId].closingTime + vestingConfig.cliff) {
            //no need for vesting when cliff already expired.
            stakingConfig.stakedToken.safeTransfer(msg.sender, vestedStakes);
        } else {
            stakingConfig.stakedToken.safeTransfer(address(stakingConfig.stakesVestingContract), vestedStakes);
            stakingConfig.stakesVestingContract.createVestingSchedule(
                msg.sender, _sales[saleId].closingTime, vestingConfig.cliff, vestingConfig.cliff, 60, false, vestedStakes
            );
        }
    }
}
