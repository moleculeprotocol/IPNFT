// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";

import { MyToken } from "../src/MyToken.sol";

contract CrowdSaleFuzzTest is Test {
    address emitter = makeAddr("emitter");

    MyToken internal auctionToken;
    MyToken internal biddingToken;
    CrowdSale internal crowdSale;

    address anyone = makeAddr("anyone");

    function setUp() public {
        crowdSale = new CrowdSale();
        auctionToken = new MyToken();
        biddingToken = new MyToken();
    }

    //todo: improve this test
    function testFuzzManyBidders(uint8 bidders, uint256 salesAmt, uint256 fundingGoal) public {
        vm.assume(0 < bidders && bidders < 10);
        vm.assume(salesAmt <= 100_000_000 ether);
        vm.assume(fundingGoal <= 100_000_000 ether);
        vm.assume(salesAmt > 0);
        vm.assume(fundingGoal > 0);

        auctionToken.mint(emitter, salesAmt);
        vm.startPrank(emitter);
        Sale memory _sale = Sale({
            auctionToken: IERC20(address(auctionToken)),
            biddingToken: IERC20(address(biddingToken)),
            fundingGoal: fundingGoal,
            salesAmount: salesAmt,
            fixedPrice: 2 ether
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
