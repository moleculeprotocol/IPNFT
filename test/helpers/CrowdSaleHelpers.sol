// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, BadSaleDuration, BalanceTooLow, SaleAlreadyActive } from "../../src/crowdsale/CrowdSale.sol";

library CrowdSaleHelpers {
    function makeSale(address beneficiary, IERC20 auctionToken, IERC20 biddingToken) internal view returns (Sale memory sale) {
        return Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20(address(biddingToken)),
            beneficiary: beneficiary,
            fundingGoal: 200_000 ether,
            salesAmount: 400_000 ether,
            closingTime: uint64(block.timestamp + 2 hours)
        });
    }
}
