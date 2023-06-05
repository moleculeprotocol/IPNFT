// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../TimelockedToken.sol";
import { LockingCrowdSale, LockingConfig, IncompatibleLockingContract, UnsupportedInitializer } from "./LockingCrowdSale.sol";
import { CrowdSale, Sale, BadDecimals } from "./CrowdSale.sol";

struct StakingInfo {
    //e.g. VITA DAO token
    IERC20Metadata stakedToken;
    TokenVesting stakesVestingContract;
    //fix price (always expressed at 1e18): stake tokens / bid token
    //see https://github.com/moleculeprotocol/IPNFT/pull/100
    uint256 wadFixedStakedPerBidPrice;
}

error UnmanageablelockingContract();
error BadPrice();
error InvalidDuration();

/**
 * @title StakedLockingCrowdSale
 * @author molecule.to
 * @notice a fixed price sales base contract that locks the sold tokens in a configured locking contract and requires vesting another ("dao") token for a certain period of time to participate
 */
contract StakedLockingCrowdSale is LockingCrowdSale {
    using SafeERC20 for IERC20Metadata;
    using FixedPointMathLib for uint256;

    mapping(uint256 => StakingInfo) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) internal stakes;

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale, LockingConfig lockingConfig, StakingInfo staking);
    event Staked(uint256 indexed saleId, address indexed bidder, uint256 stakedAmount, uint256 price);
    event ClaimedStakes(uint256 indexed saleId, address indexed claimer, uint256 stakesClaimed, uint256 stakesRefunded);

    /// @dev disable parent sale starting functions
    function startSale(Sale calldata, TimelockedToken, uint256) public pure override returns (uint256) {
        revert UnsupportedInitializer();
    }

    /**
     * @notice if lockingContract is 0x0, a new timelocked token vesting contract clone is automatically created
     *
     * @param sale sale configuration
     * @param stakedToken the ERC20 contract for staking tokens
     * @param stakesVestingContract the TokenVesting contract for vested staking tokens
     * @param wadFixedStakedPerBidPrice the 10e18 based float price for stakes/bid tokens
     * @param lockingContract contract that locks claimed auction tokens
     * @param duration duration until stakes and auction tokens are locked or vested
     * @return saleId
     */
    function startSale(
        Sale calldata sale,
        IERC20Metadata stakedToken,
        TokenVesting stakesVestingContract,
        uint256 wadFixedStakedPerBidPrice,
        TimelockedToken lockingContract,
        uint256 duration
    ) public returns (uint256 saleId) {
        if (IERC20Metadata(address(stakedToken)).decimals() != 18) {
            revert BadDecimals();
        }

        if (!stakesVestingContract.hasRole(stakesVestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
            revert UnmanageablelockingContract();
        }

        if (address(stakesVestingContract.nativeToken()) != address(stakedToken)) {
            revert IncompatibleLockingContract();
        }

        // duration must follow the same rules as `TokenVesting` cliffs
        if (duration < 7 days || duration > 50 * (365 days)) {
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
        salesStaking[saleId] = StakingInfo(stakedToken, stakesVestingContract, wadFixedStakedPerBidPrice);
        super.startSale(sale, lockingContract, duration);
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
        emit Started(saleId, msg.sender, _sales[saleId], salesLocking[saleId], salesStaking[saleId]);
    }

    /**
     * @dev computes stake returns for a bidder
     *
     * @param saleId sale id
     * @param refunds amount of bidding tokens being refunded
     * @return refundedStakes wei value of refunded staking tokens
     * @return vestedStakes wei value of staking tokens returned wrapped as vesting tokens
     */
    function getClaimableStakes(uint256 saleId, uint256 refunds) public view virtual returns (uint256 refundedStakes, uint256 vestedStakes) {
        StakingInfo storage staking = salesStaking[saleId];

        refundedStakes = refunds.mulWadDown(staking.wadFixedStakedPerBidPrice);
        vestedStakes = stakes[saleId][msg.sender] - refundedStakes;
    }

    /**
     * @dev calculates the amount of required staking tokens using the provided fix price
     *      will revert if bidder hasn't approved / owns a sufficient amount of staking tokens
     */
    function _bid(uint256 saleId, uint256 biddingTokenAmount) internal virtual override {
        StakingInfo storage staking = salesStaking[saleId];

        uint256 stakedTokenAmount = biddingTokenAmount.mulWadDown(staking.wadFixedStakedPerBidPrice);

        stakes[saleId][msg.sender] += stakedTokenAmount;

        staking.stakedToken.safeTransferFrom(msg.sender, address(this), stakedTokenAmount);

        super._bid(saleId, biddingTokenAmount);
        emit Staked(saleId, msg.sender, stakedTokenAmount, staking.wadFixedStakedPerBidPrice);
    }

    /**
     * @notice refunds stakes and locks active stakes in vesting contract
     * @dev super.claim transitively calls LockingCrowdSale:_claimAuctionTokens
     * @inheritdoc CrowdSale
     */
    function claim(uint256 saleId, uint256 tokenAmount, uint256 refunds) internal virtual override {
        LockingConfig storage lockingConfig = salesLocking[saleId];
        StakingInfo storage staking = salesStaking[saleId];
        (uint256 refundedStakes, uint256 vestedStakes) = getClaimableStakes(saleId, refunds);

        //EFFECTS
        //this prevents msg.sender to claim twice
        stakes[saleId][msg.sender] = 0;

        // INTERACTIONS
        super.claim(saleId, tokenAmount, refunds);

        if (refundedStakes != 0) {
            staking.stakedToken.safeTransfer(msg.sender, refundedStakes);
        }

        emit ClaimedStakes(saleId, msg.sender, vestedStakes, refundedStakes);

        if (vestedStakes == 0) {
            return;
        }

        if (block.timestamp > _sales[saleId].closingTime + lockingConfig.duration) {
            //no need for vesting when duration already expired.
            staking.stakedToken.safeTransfer(msg.sender, vestedStakes);
        } else {
            staking.stakedToken.safeTransfer(address(staking.stakesVestingContract), vestedStakes);
            staking.stakesVestingContract.createVestingSchedule(
                msg.sender, _sales[saleId].closingTime, lockingConfig.duration, lockingConfig.duration, 60, false, vestedStakes
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
        emit ClaimedStakes(saleId, msg.sender, 0, refundableStakes);

        salesStaking[saleId].stakedToken.safeTransfer(msg.sender, refundableStakes);
    }
}
