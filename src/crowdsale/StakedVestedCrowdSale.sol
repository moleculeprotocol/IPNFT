// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

import { VestedCrowdSale, VestingConfig, ApprovalFailed, IncompatibleVestingContract, UnmanageableVestingContract } from "./VestedCrowdSale.sol";
import { CrowdSale, Sale, BadDecimals, SaleState } from "./CrowdSale.sol";
import { InitializeableTokenVesting } from "./InitializableTokenVesting.sol";
import { IPriceFeedConsumer } from "../BioPriceFeed.sol";

struct StakingConfig {
    IERC20 stakedToken; //eg VITA DAO token
    TokenVesting stakesVestingContract;
    uint256 wadFixedDaoPerBidPrice;
    uint256 stakeTotal; //initialize with 0
}

error BadPrice();

contract StakedVestedCrowdSale is VestedCrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => StakingConfig) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) stakes;

    //IPriceFeedConsumer priceFeed;

    event Started(uint256 saleId, address indexed issuer, Sale sale, VestingConfig vesting, StakingConfig staking);
    event Staked(uint256 indexed saleId, address indexed bidder, uint256 stakedAmount, uint256 price);
    // constructor(IPriceFeedConsumer priceFeed_) VestedCrowdSale() {
    //     priceFeed = priceFeed_;
    // }

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

        if (stakingConfig.wadFixedDaoPerBidPrice == 0) {
            revert BadPrice();
        }
        //todo: duck type check whether all token contracts can do what we need.
        //don't let users create a sale with "bad" values
        stakingConfig.stakeTotal = 0;
        //stakingConfig.wadDaoInBidPrice = uint256(priceFeed.getPrice(address(sale.biddingToken), address(stakedToken)));

        saleId = uint256(keccak256(abi.encode(sale)));
        salesStaking[saleId] = stakingConfig;
        super.startSale(sale, vestingConfig);
    }

    function _onSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId], salesStaking[saleId]);
    }

    function stakesOf(uint256 saleId, address bidder) public view returns (uint256) {
        return stakes[saleId][bidder];
    }

    function settle(uint256 saleId) public override {
        super.settle(saleId);
        if (_saleInfo[saleId].state == SaleState.FAILED) {
            return;
        }

        StakingConfig storage staking = salesStaking[saleId];
        bool result = staking.stakedToken.approve(address(staking.stakesVestingContract), staking.stakeTotal);
        if (!result) {
            revert ApprovalFailed();
        }
    }

    function _bid(uint256 saleId, uint256 biddingTokenAmount) internal virtual override {
        StakingConfig storage staking = salesStaking[saleId];

        //todo use current price:
        //uint256 wadDaoInBiddingPrice = uint256(priceFeed.getPrice(address(_sales[saleId].biddingToken), address(staking.stakedToken)));
        // if (wadDaoInBiddingPrice == 0) {
        //     revert("no price available");
        // }

        uint256 stakedTokenAmount = FP.mulWadDown(biddingTokenAmount, staking.wadFixedDaoPerBidPrice);

        staking.stakeTotal += stakedTokenAmount;
        stakes[saleId][msg.sender] += stakedTokenAmount;

        staking.stakedToken.safeTransferFrom(msg.sender, address(this), stakedTokenAmount);

        super._bid(saleId, biddingTokenAmount);
        emit Staked(saleId, msg.sender, stakedTokenAmount, staking.wadFixedDaoPerBidPrice);
    }

    //todo: get final price as by price feed at settlement
    function claim(uint256 saleId, uint256 auctionTokens, uint256 refunds) internal virtual override {
        VestingConfig memory vestingConfig = salesVesting[saleId];
        StakingConfig memory stakingConfig = salesStaking[saleId];

        uint256 _stakes = stakes[saleId][msg.sender];

        super.claim(saleId, auctionTokens, refunds);

        uint256 refundedStakes = FP.mulWadDown(refunds, stakingConfig.wadFixedDaoPerBidPrice);
        uint256 vestedStakes = _stakes - refundedStakes;
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
