// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";

import { MyToken } from "../src/MyToken.sol";

contract CrowdSaleTest is Test {
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    MyToken internal auctionToken;
    MyToken internal biddingToken;
    CrowdSale internal crowdSale;

    function setUp() public {
        crowdSale = new CrowdSale();
        auctionToken = new MyToken();
        biddingToken = new MyToken();

        auctionToken.mint(emitter, 500_000 ether);
        biddingToken.mint(bidder, 1_000_000 ether);
        biddingToken.mint(bidder2, 1_000_000 ether);
    }

    function makeSale() internal returns (Sale memory sale) {
        return Sale({
            auctionToken: IERC20(address(auctionToken)),
            biddingToken: IERC20(address(biddingToken)),
            fundingGoal: 200_000 ether,
            salesAmount: 400_000 ether,
            fixedPrice: 2 ether
        });
    }

    function testCreateSale() public {
        vm.startPrank(emitter);

        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        crowdSale.startSale(_sale);
        vm.stopPrank();
    }

    function testPlaceBid() public {
        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 200_000 ether);
        crowdSale.placeBid(saleId, 100_000 ether);
        assertEq(crowdSale.contribution(saleId, bidder), 100_000 ether);
        crowdSale.placeBid(saleId, 100_000 ether);
        assertEq(crowdSale.contribution(saleId, bidder), 200_000 ether);
        vm.stopPrank();
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 200_000 ether);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.saleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
    }

    function testTwoBiddersMeetExactly() public {
        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 150_000 ether);
        crowdSale.placeBid(saleId, 150_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        biddingToken.approve(address(crowdSale), 50_000 ether);
        crowdSale.placeBid(saleId, 50_000 ether);
        vm.stopPrank();

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 300_000 ether);
        assertEq(auctionToken.balanceOf(bidder2), 100_000 ether);
    }

    function testRefundsOnOverbid() public {
        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        crowdSale.placeBid(saleId, 1_000_000 ether);
        vm.stopPrank();
        assertEq(biddingToken.balanceOf(bidder), 0);

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 400_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 800_000 ether);
    }
}
