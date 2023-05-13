// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, BadSaleDuration, BalanceTooLow, SaleAlreadyActive } from "../src/crowdsale/CrowdSale.sol";
import { FakeERC20 } from "./helpers/FakeERC20.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

contract CrowdSaleTest is Test {
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    CrowdSale internal crowdSale;

    function setUp() public {
        crowdSale = new CrowdSale();
        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");

        auctionToken.mint(emitter, 500_000 ether);
        biddingToken.mint(bidder, 1_000_000 ether);
        biddingToken.mint(bidder2, 1_000_000 ether);

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();
    }

    function testCreateSale() public {
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);

        vm.startPrank(emitter);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        crowdSale.startSale(_sale);
        vm.stopPrank();

        //cant create the same sale twice
        vm.startPrank(emitter);
        auctionToken.mint(emitter, 300_000 ether);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        vm.expectRevert(SaleAlreadyActive.selector);
        crowdSale.startSale(_sale);
        vm.stopPrank();
    }

    function testCannotCreateSaleWithoutFunds() public {
        address poorguy = makeAddr("poorguy");
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);

        vm.startPrank(poorguy);
        vm.expectRevert(BalanceTooLow.selector);
        crowdSale.startSale(_sale);
        vm.stopPrank();
    }

    function testPlaceBid() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);

        crowdSale.placeBid(saleId, 100_000 ether);
        assertEq(crowdSale.contribution(saleId, bidder), 100_000 ether);

        crowdSale.placeBid(saleId, 100_000 ether);
        assertEq(crowdSale.contribution(saleId, bidder), 200_000 ether);
        vm.stopPrank();
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
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
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
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

    function testSingleRefundsOnOvershoot() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
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

    function testOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 400_000 ether);
        vm.stopPrank();
        /*
        800_000 are bid
        200_000 were requested
        600_000 are overshot
        (400_000 auction tokens are distributed)

        bidder added 600_000
        bidder receives 3/4 of 400_000 = 300_000
        bidder is refunded  3/4 of 600_000 = 450_000
        bidder's final balance = 400_000 + 450_000 = 850_000

        bidder2 added 200_000
        bidder2 receives 1/4 of 400_000 = 100_000
        bidder2 is refunded 1/4 of 600_000 = 150_000
        bidder2's final balance = 800_000 + 150_000 = 950_000
        */
        // vm.startPrank(bidder);
        // crowdSale.placeBid(saleId, 300_000 ether); //overshoot 200k
        // vm.stopPrank();

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
        assertEq(biddingToken.balanceOf(bidder), 850_000 ether);

        assertEq(auctionToken.balanceOf(bidder2), 100_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 950_000 ether);

        assertEq(auctionToken.balanceOf(address(crowdSale)), 0);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnevenOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 380_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 450_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 230_000 ether);
        vm.stopPrank();
        /*
        1_060_000 are bid
        200_000 were requested
        860_000 are overshot
        (400_000 auction tokens are distributed)

        bidder added 610_000 (0.575471 / x of all bids)
        bidder receives x * 400_000 = 230188.4
        bidder is refunded  x of 860_000 = 494905
        bidder's final balance = 390000 + 494905 = 884905

        bidder2 added 450_000 (0.424528302 / y of all bids)
        bidder2 receives y * 400_000 = 169811.3208
        bidder2 is refunded y of 860_000 = 365094.33972
        bidder2's final balance = 550000 + 365094 = 915094

        total received 230188.4 + 169811.3208 = 399_999
        total refunded 860_000
        */

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 230188679245283018800000);
        assertEq(biddingToken.balanceOf(bidder), 884905660377358490420000);

        assertEq(auctionToken.balanceOf(bidder2), 169811320754716980800000);
        assertEq(biddingToken.balanceOf(bidder2), 915094339622641508720000);

        assertEq(biddingToken.balanceOf(emitter), 200_000 ether);

        //some dust is left on the table
        //these are 0.0000000000004 tokens at 18 decimals
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 860_000);
    }
}
