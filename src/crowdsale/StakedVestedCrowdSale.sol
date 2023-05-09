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

struct StakingConfig {
    IERC20 stakedToken; //eg VITA DAO token
    TokenVesting stakesVestingContract;
    uint256 auctionInBiddingPrice;
    uint256 wadDaoInBidPriceAtSettlement;
    uint256 stakeTotal; //initialize with 0
}

contract StakedVestedCrowdSale is VestedCrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => StakingConfig) public salesStaking;
    mapping(uint256 => mapping(address => uint256)) stakes;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //address immutable tokenImplementation;

    // constructor() {
    //     tokenImplementation = address(new InitializeableTokenVesting(IERC20Metadata(address(new FakeIERC20())), "",""));
    // }

    function startSale(Sale memory sale, VestingConfig memory vesting, StakingConfig memory stakingConfig) public returns (uint256 saleId) {
        salesStaking[saleId] = stakingConfig;
        saleId = super.startSale(sale, vesting);
    }

    function startSale(Sale memory sale, StakingConfig memory stakingConfig, uint256 cliff, uint256 duration) public returns (uint256 saleId) {
        saleId = super.startSale(sale, cliff, duration);
        salesStaking[saleId] = stakingConfig;
    }

    function startSale(Sale memory sale, IERC20 stakedToken, TokenVesting stakesVesting, uint256 initialPrice, uint256 cliff, uint256 duration)
        public
        returns (uint256 saleId)
    {
        //1 DAO = 1 bid, current price
        uint256 wadDaoInBiddingPrice = 1 * FP.WAD;

        return startSale(sale, StakingConfig(stakedToken, stakesVesting, initialPrice, wadDaoInBiddingPrice, 0), cliff, duration);
    }

    function stakesOf(uint256 saleId, address bidder) public view returns (uint256) {
        return stakes[saleId][bidder];
    }

    function settle(uint256 saleId) public override {
        super.settle(saleId);
        StakingConfig storage staking = salesStaking[saleId];
        //1 DAO = 1 bid
        staking.wadDaoInBidPriceAtSettlement = 1 * FP.WAD;
        staking.stakedToken.approve(address(staking.stakesVestingContract), staking.stakeTotal);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) public override {
        StakingConfig storage staking = salesStaking[saleId];

        //todo price calculation here:
        uint256 stakedTokenAmount = biddingTokenAmount;

        staking.stakeTotal += stakedTokenAmount;
        stakes[saleId][msg.sender] += stakedTokenAmount;

        staking.stakedToken.safeTransferFrom(msg.sender, address(this), stakedTokenAmount);
        super.placeBid(saleId, biddingTokenAmount);
    }

    //todo: get final price as by price feed at settlement
    function claim(uint256 saleId) public override returns (uint256 auctionTokens, uint256 refunds) {
        VestingConfig memory vestingConfig = salesVesting[saleId];
        StakingConfig memory stakingConfig = salesStaking[saleId];

        uint256 _stakes = stakes[saleId][msg.sender];

        (auctionTokens, refunds) = super.claim(saleId);

        uint256 refundedStakes = FP.mulWadDown(refunds, stakingConfig.wadDaoInBidPriceAtSettlement);
        uint256 vestedStakes = _stakes - refundedStakes;

        salesStaking[saleId].stakesVestingContract.createPublicVestingSchedule(
            msg.sender, block.timestamp, vestingConfig.cliff, vestingConfig.duration, 60, vestedStakes
        );
        salesStaking[saleId].stakedToken.safeTransfer(msg.sender, refundedStakes);
    }
}
