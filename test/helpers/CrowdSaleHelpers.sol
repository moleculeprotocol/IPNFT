// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, BadSaleDuration, BalanceTooLow, SaleAlreadyActive } from "../../src/crowdsale/CrowdSale.sol";
import { IPermissioner } from "../../src/Permissioner.sol";

library CrowdSaleHelpers {
    function makeSale(address beneficiary, IERC20Metadata auctionToken, IERC20Metadata biddingToken) internal view returns (Sale memory sale) {
        return Sale({
            auctionToken: auctionToken,
            biddingToken: biddingToken,
            beneficiary: beneficiary,
            fundingGoal: 200_000 ether,
            salesAmount: 400_000 ether,
            closingTime: uint64(block.timestamp + 2 hours),
            permissioner: IPermissioner(address(0x0))
        });
    }
}
