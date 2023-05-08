// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";

import { FakeERC20 } from "./helpers/FakeERC20.sol";

contract CrowdSaleFuzzTest is Test {
    address emitter = makeAddr("emitter");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    CrowdSale internal crowdSale;

    address anyone = makeAddr("anyone");

    function setUp() public {
        crowdSale = new CrowdSale();
        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");
    }

    //todo: improve this test
    function testFuzzManyBidders(uint8 bidders, uint96 salesAmt, uint96 fundingGoal) public {
        vm.assume(bidders > 0 && bidders < 25);
        vm.assume(salesAmt > 0);
        vm.assume(fundingGoal > 0);

        auctionToken.mint(emitter, salesAmt);
        vm.startPrank(emitter);
        Sale memory _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20(address(biddingToken)),
            fundingGoal: fundingGoal,
            salesAmount: salesAmt,
            closingTime: 0
        });

        auctionToken.approve(address(crowdSale), salesAmt);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        for (uint8 it = 0; it < bidders; it++) {
            address someone = makeAddr(string(abi.encode("bidder", it)));

            vm.startPrank(someone);
            uint256 bid = 1000 ether;
            biddingToken.mint(someone, bid);
            biddingToken.approve(address(crowdSale), bid);
            crowdSale.placeBid(saleId, bid);
            vm.stopPrank();
        }
        vm.startPrank(anyone);
        try crowdSale.settle(saleId) {
            return;
        } catch Error(string memory err) {
            //console.log(err);
        }
        vm.stopPrank();
    }
}
