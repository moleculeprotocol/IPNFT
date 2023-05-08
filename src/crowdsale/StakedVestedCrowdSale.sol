// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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
        return startSale(sale, StakingConfig(stakedToken, stakesVesting, initialPrice, 0), cliff, duration);
    }

    function settle(uint256 saleId) public override {
        super.settle(saleId);
        StakingConfig memory staking = salesStaking[saleId];
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

    function claim(uint256 saleId) public override returns (uint256 auctionTokens, uint256 refunds, uint256 biddingRatio) {
        VestingConfig memory vestingConfig = salesVesting[saleId];

        uint256 _stakes = stakes[saleId][msg.sender];

        (auctionTokens, refunds, biddingRatio) = super.claim(saleId);
        uint256 usedStakes = FP.mulWadDown(biddingRatio, _stakes);
        uint256 refundedStakes = _stakes - usedStakes;

        salesStaking[saleId].stakesVestingContract.createPublicVestingSchedule(
            msg.sender, block.timestamp, vestingConfig.cliff, vestingConfig.duration, 60, usedStakes
        );
        salesStaking[saleId].stakedToken.safeTransfer(msg.sender, refundedStakes);
    }
}
