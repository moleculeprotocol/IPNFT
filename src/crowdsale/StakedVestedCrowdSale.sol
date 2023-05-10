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

import { VestedCrowdSale, VestingConfig } from "./VestedCrowdSale.sol";
import { CrowdSale, Sale } from "./CrowdSale.sol";
import { InitializeableTokenVesting } from "./InitializableTokenVesting.sol";
import { IPriceFeedConsumer } from "../BioPriceFeed.sol";

struct StakingConfig {
    IERC20 stakedToken; //eg VITA DAO token
    TokenVesting stakesVestingContract;
    uint256 wadFixedDaoInBidPrice;
    uint256 stakeTotal; //initialize with 0
}

contract StakedVestedCrowdSale is VestedCrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => StakingConfig) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) stakes;

    IPriceFeedConsumer priceFeed;

    event Bid(uint256 indexed saleId, address indexed bidder, uint256 stakedAmount, uint256 amount, uint256 price);

    constructor(IPriceFeedConsumer priceFeed_) VestedCrowdSale() {
        priceFeed = priceFeed_;
    }

    function startSale(Sale memory sale, VestingConfig memory vesting, StakingConfig memory stakingConfig) public returns (uint256 saleId) {
        salesStaking[saleId] = stakingConfig;
        saleId = super.startSale(sale, vesting);
    }

    function startSale(Sale memory sale, StakingConfig memory stakingConfig, uint256 cliff, uint256 duration) public returns (uint256 saleId) {
        saleId = super.startSale(sale, cliff, duration);
        salesStaking[saleId] = stakingConfig;
    }

    function startSale(Sale memory sale, IERC20 stakedToken, TokenVesting stakesVesting, uint256 daoPrice, uint256 cliff, uint256 duration)
        public
        returns (uint256 saleId)
    {
        uint256 wadDaoInBidPrice = uint256(priceFeed.getPrice(address(sale.biddingToken), address(stakedToken)));

        return startSale(sale, StakingConfig(stakedToken, stakesVesting, wadDaoInBidPrice, 0), cliff, duration);
    }

    function stakesOf(uint256 saleId, address bidder) public view returns (uint256) {
        return stakes[saleId][bidder];
    }

    function settle(uint256 saleId) public override {
        super.settle(saleId);
        StakingConfig storage staking = salesStaking[saleId];
        staking.stakedToken.approve(address(staking.stakesVestingContract), staking.stakeTotal);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) public override {
        StakingConfig storage staking = salesStaking[saleId];

        //todo price calculation here:
        uint256 price = 1;
        uint256 stakedTokenAmount = biddingTokenAmount;

        //uint256 price = priceFeed.getPrice(sale.biddingToken, staking.stakedToken);
        uint256 wadDaoInBiddingPrice = uint256(priceFeed.getPrice(address(_sales[saleId].biddingToken), address(staking.stakedToken)));
        if (wadDaoInBiddingPrice == 0) {
            revert("no price available");
        }

        stakedTokenAmount = FP.mulWadDown(biddingTokenAmount, wadDaoInBiddingPrice);

        staking.stakeTotal += stakedTokenAmount;
        stakes[saleId][msg.sender] += stakedTokenAmount;

        emit Bid(saleId, msg.sender, biddingTokenAmount, stakedTokenAmount, price);
        staking.stakedToken.safeTransferFrom(msg.sender, address(this), stakedTokenAmount);

        super.placeBid(saleId, biddingTokenAmount);
    }

    //todo: get final price as by price feed at settlement
    function claim(uint256 saleId) public override returns (uint256 auctionTokens, uint256 refunds) {
        VestingConfig memory vestingConfig = salesVesting[saleId];
        StakingConfig memory stakingConfig = salesStaking[saleId];

        uint256 _stakes = stakes[saleId][msg.sender];

        (auctionTokens, refunds) = super.claim(saleId);

        uint256 refundedStakes = FP.mulWadDown(refunds, stakingConfig.wadFixedDaoInBidPrice);
        uint256 vestedStakes = _stakes - refundedStakes;

        salesStaking[saleId].stakedToken.safeTransfer(address(salesStaking[saleId].stakesVestingContract), vestedStakes);
        salesStaking[saleId].stakesVestingContract.createVestingSchedule(
            msg.sender, block.timestamp, vestingConfig.cliff, vestingConfig.duration, 60, false, vestedStakes
        );
        salesStaking[saleId].stakedToken.safeTransfer(msg.sender, refundedStakes);
    }
}
