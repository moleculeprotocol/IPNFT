// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../TimelockedToken.sol";
import { VestedCrowdSale, VestingConfig, IncompatibleVestingContract, UnmanageableVestingContract } from "./VestedCrowdSale.sol";
import { CrowdSale, Sale, BadDecimals } from "./CrowdSale.sol";

struct StakingInfo {
    //e.g. VITA DAO token
    IERC20Metadata stakedToken;
    TokenVesting stakesVestingContract;
    //fix price (always expressed at 1e18): stake tokens / bid token
    //see https://github.com/moleculeprotocol/IPNFT/pull/100
    uint256 wadFixedStakedPerBidPrice;
    uint256 stakeTotal;
}

error BadPrice();
error InvalidDuration();

/**
 * @title StakedVestedCrowdSale
 * @author molecule.to
 * @notice a fixed price sales base contract that locks the sold tokens in a configured vesting scheme and requires lock-vesting another ("dao") token for a certain period of time to participate
 */
contract StakedVestedCrowdSale is VestedCrowdSale {
    using SafeERC20 for IERC20Metadata;
    using FixedPointMathLib for uint256;

    mapping(uint256 => StakingInfo) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) internal stakes;

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale, VestingConfig vesting, StakingInfo staking);
    event Staked(uint256 indexed saleId, address indexed bidder, uint256 stakedAmount, uint256 price);

    /**
     * @notice if vestingContract is 0x0, a new timelocked token vesting contract clone is automatically created
     *
     * @param sale sale configuration
     * @param stakedToken the ERC20 contract for staking tokens
     * @param stakesVestingContract the TokenVesting contract for vested staking tokens
     * @param wadFixedStakedPerBidPrice the 10e18 based float price for stakes/bid tokens
     * @param vestingContract the vesting contract for vested auction tokens
     * @param cliff duration until stakes and auction tokens are vested
     * @return saleId
     */
    function startSale(
        Sale calldata sale,
        IERC20Metadata stakedToken,
        TokenVesting stakesVestingContract,
        uint256 wadFixedStakedPerBidPrice,
        TimelockedToken vestingContract,
        uint256 cliff
    ) public returns (uint256 saleId) {
        if (IERC20Metadata(address(stakedToken)).decimals() != 18) {
            revert BadDecimals();
        }

        if (!stakesVestingContract.hasRole(stakesVestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
            revert UnmanageableVestingContract();
        }

        if (address(stakesVestingContract.nativeToken()) != address(stakedToken)) {
            revert IncompatibleVestingContract();
        }

        // cliff duration must follow the same rules as `TokenVesting`
        if (cliff < 7 days || cliff > 50 * (365 days)) {
            revert InvalidDuration();
        }

        if (wadFixedStakedPerBidPrice == 0) {
            revert BadPrice();
        }

        //if the bidding token (eg USDC) does not come with 18 decimals, we're adjusting the price here.
        //see https://github.com/moleculeprotocol/IPNFT/pull/100
        if (sale.biddingToken.decimals() != 18) {
            wadFixedStakedPerBidPrice = (wadFixedStakedPerBidPrice * 10 ** 18) / 10 ** sale.biddingToken.decimals();
        }

        saleId = uint256(keccak256(abi.encode(sale)));
        salesStaking[saleId] = StakingInfo(stakedToken, stakesVestingContract, wadFixedStakedPerBidPrice, 0);
        super.startSale(sale, vestingContract, cliff);
    }

    /**
     * @return uint256 how many stakingTokens `bidder` has staked into sale `saleId`
     */
    function stakesOf(uint256 saleId, address bidder) external view returns (uint256) {
        return stakes[saleId][bidder];
    }

    /**
     * @dev emits a custom event for this crowdsale class
     */
    function _afterSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId], salesStaking[saleId]);
    }

    /**
     * @dev computes stake returns
     *
     * @param _stakes the amount of staking tokens bid to the sale
     * @param refunds amount of bidding tokens being refunded
     * @param price the 1e18 based float price of stake per bid (`wadFixedStakedPerBidPrice`)
     * @return refundedStakes wei value of refunded staking tokens
     * @return vestedStakes wei value of staking tokens returned wrapped as vesting tokens
     */
    function getClaimableStakes(uint256 _stakes, uint256 refunds, uint256 price) public pure returns (uint256 refundedStakes, uint256 vestedStakes) {
        refundedStakes = refunds.mulWadDown(price);
        vestedStakes = _stakes - refundedStakes;
    }

    /**
     * @dev calculates the amount of required staking tokens using the provided fix price
     *      will revert if bidder hasn't approved / owns a sufficient amount of staking tokens
     */
    function _bid(uint256 saleId, uint256 biddingTokenAmount) internal virtual override {
        StakingInfo storage staking = salesStaking[saleId];

        uint256 stakedTokenAmount = biddingTokenAmount.mulWadDown(staking.wadFixedStakedPerBidPrice);

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
        VestingConfig storage vestingConfig = salesVesting[saleId];
        StakingInfo storage staking = salesStaking[saleId];

        (uint256 refundedStakes, uint256 vestedStakes) = getClaimableStakes(stakes[saleId][msg.sender], refunds, staking.wadFixedStakedPerBidPrice);

        //EFFECTS
        //this prevents msg.sender to claim twice
        stakes[saleId][msg.sender] = 0;

        // INTERACTIONS
        super.claim(saleId, tokenAmount, refunds);

        if (refundedStakes != 0) {
            staking.stakedToken.safeTransfer(msg.sender, refundedStakes);
        }

        if (vestedStakes == 0) {
            return;
        }

        if (block.timestamp > _sales[saleId].closingTime + vestingConfig.cliff) {
            //no need for vesting when cliff already expired.
            staking.stakedToken.safeTransfer(msg.sender, vestedStakes);
        } else {
            staking.stakedToken.safeTransfer(address(staking.stakesVestingContract), vestedStakes);
            staking.stakesVestingContract.createVestingSchedule(
                msg.sender, _sales[saleId].closingTime, vestingConfig.cliff, vestingConfig.cliff, 60, false, vestedStakes
            );
        }
    }

    /**
     * @notice will additionally charge back all staked tokens
     * @inheritdoc CrowdSale
     */
    function claimFailed(uint256 saleId) internal override returns (uint256 auctionTokens, uint256 refunds) {
        uint256 refundableStakes = stakes[saleId][msg.sender];
        stakes[saleId][msg.sender] = 0;

        (auctionTokens, refunds) = super.claimFailed(saleId);
        salesStaking[saleId].stakedToken.safeTransfer(msg.sender, refundableStakes);
    }
}
