// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { CrowdSale, Sale } from "./CrowdSale.sol";

struct VestingConfig {
    TokenVesting vestingContract;
    uint256 cliff;
    uint256 duration;
}

contract VestedCrowdSale is CrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => VestingConfig) _salesVesting;

    function startSale(Sale memory sale, VestingConfig memory vesting) external returns (uint256 saleId) {
        saleId = super.startSale(sale);
        _salesVesting[saleId] = vesting;
    }

    function startSaleWithNewVestingToken(Sale memory sale, uint256 cliff, uint256 duration) external {
        //todo: clone a new TokenVesting ERC20 contract and call start sale with that one
    }

    function settle(uint256 saleId) public override {
        Sale memory sale = _sales[saleId];
        VestingConfig memory vesting = _salesVesting[saleId];

        super.settle(saleId);

        _sales[saleId].auctionToken.approve(address(vesting.vestingContract), sale.salesAmount);
    }

    function claim(uint256 saleId) external override {
        //todo: check that sale exists
        (uint256 auctionTokens, uint256 refunds) = getClaimableAmounts(saleId, msg.sender);
        if (auctionTokens == 0) {
            revert("nothing to claim");
        }

        VestingConfig memory vesting = _salesVesting[saleId];
        if (refunds > 0) {
            _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds);
        }

        vesting.vestingContract.createPublicVestingSchedule(msg.sender, block.timestamp, vesting.cliff, vesting.duration, 60, auctionTokens);
        //todo emit vesting schedule id here
    }
}
