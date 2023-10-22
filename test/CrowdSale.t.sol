// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    CrowdSale,
    SaleState,
    Sale,
    SaleInfo,
    AlreadyClaimed,
    BadSalesAmount,
    BadSaleDuration,
    SaleAlreadyActive,
    SaleClosedForBids,
    BidTooLow,
    SaleNotFund,
    SaleNotConcluded,
    BadSaleState,
    FeesTooHigh
} from "../src/crowdsale/CrowdSale.sol";
import { IPermissioner } from "../src/Permissioner.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

contract CrowdSaleTest is Test {
    address deployer = makeAddr("chucknorris");
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    FakeERC20 internal usdc6;
    CrowdSale internal crowdSale;

    function setUp() public {
        vm.startPrank(deployer);
        crowdSale = new CrowdSale();
        vm.stopPrank();
        auctionToken = new FakeERC20("IPTOKENS","IPT");
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

    function testOwnerCanControlFees() public {
        assertEq(crowdSale.currentFeeBp(), 0);
        assertEq(crowdSale.owner(), deployer);

        vm.startPrank(anyone);
        vm.expectRevert("Ownable: caller is not the owner");
        crowdSale.setCurrentFeesBp(2500);
        vm.stopPrank();

        vm.startPrank(deployer);
        vm.expectRevert(FeesTooHigh.selector);
        crowdSale.setCurrentFeesBp(5001);

        //10%
        crowdSale.setCurrentFeesBp(1000);
        assertEq(crowdSale.currentFeeBp(), 1000);
        vm.stopPrank();
    }

    function testCreateSale() public {
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);

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
        Sale memory _sale = CrowdSaleHelpers.makeSale(poorguy, auctionToken, biddingToken);

        vm.startPrank(poorguy);
        vm.expectRevert("ERC20: insufficient allowance");
        crowdSale.startSale(_sale);
        vm.stopPrank();
    }

    function testCannotInitializeSaleWithBadParams() public {
        vm.startPrank(emitter);
        auctionToken.approve(address(crowdSale), 1 ether);
        Sale memory _sale = Sale({
            auctionToken: IERC20Metadata(address(0)),
            biddingToken: IERC20Metadata(address(0)),
            beneficiary: address(0),
            fundingGoal: 0,
            salesAmount: 0,
            closingTime: 0,
            permissioner: IPermissioner(address(0))
        });

        vm.expectRevert(BadSaleDuration.selector);
        crowdSale.startSale(_sale);
        _sale.closingTime = uint64(block.timestamp + 3 hours);

        vm.expectRevert();
        crowdSale.startSale(_sale);

        _sale.auctionToken = auctionToken;
        vm.expectRevert();
        crowdSale.startSale(_sale);

        _sale.biddingToken = biddingToken;
        vm.expectRevert(BadSalesAmount.selector);
        crowdSale.startSale(_sale);

        //check minimum sales amounts
        _sale.fundingGoal = 0.009 ether;
        _sale.salesAmount = 0.5 ether;
        vm.expectRevert(BadSalesAmount.selector);
        crowdSale.startSale(_sale);

        _sale.fundingGoal = 0.01 ether;
        _sale.salesAmount = 0.49 ether;
        vm.expectRevert(BadSalesAmount.selector);
        crowdSale.startSale(_sale);

        _sale.fundingGoal = 0.01 ether;
        _sale.salesAmount = 0.5 ether;
        crowdSale.startSale(_sale);

        vm.stopPrank();
    }

    function testPlaceBid() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        vm.expectRevert(BidTooLow.selector);
        crowdSale.placeBid(saleId, 0, "");

        vm.expectRevert(abi.encodeWithSelector(SaleNotFund.selector, 42));
        crowdSale.placeBid(42, 1000, "");

        crowdSale.placeBid(saleId, 100_000 ether, "");
        assertEq(crowdSale.contribution(saleId, bidder), 100_000 ether);

        crowdSale.placeBid(saleId, 100_000 ether, "");
        assertEq(crowdSale.contribution(saleId, bidder), 200_000 ether);
        vm.stopPrank();
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        assertEq(_sale.beneficiary, emitter);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        // cant settle before sale.closingTime
        vm.startPrank(anyone);
        vm.expectRevert(SaleNotConcluded.selector);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours + 1);
        // cant place bids after sale.closingTime
        vm.startPrank(bidder);
        vm.expectRevert(SaleClosedForBids.selector);
        crowdSale.placeBid(saleId, 100_000 ether, "");
        vm.stopPrank();

        // cant claim before settled
        vm.startPrank(bidder);
        vm.expectRevert(abi.encodeWithSelector(BadSaleState.selector, SaleState.SETTLED, SaleState.RUNNING));
        crowdSale.claimResults(saleId);

        vm.expectRevert(abi.encodeWithSelector(BadSaleState.selector, SaleState.SETTLED, SaleState.RUNNING));
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        crowdSale.settle(saleId);

        //can't settle twice
        vm.expectRevert(abi.encodeWithSelector(BadSaleState.selector, SaleState.RUNNING, SaleState.SETTLED));
        crowdSale.settle(saleId);
        vm.stopPrank();

        //[L-02] the emitter must claim their results manually
        assertEq(biddingToken.balanceOf(emitter), 0);
        vm.startPrank(anyone);
        crowdSale.claimResults(saleId);

        //[L-02] the results cannot be claimed twice
        vm.expectRevert(AlreadyClaimed.selector);
        crowdSale.claimResults(saleId);
        vm.stopPrank();
        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.expectRevert(abi.encodeWithSelector(BadSaleState.selector, SaleState.SETTLED, SaleState.RUNNING));
        crowdSale.claimResults(saleId);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), 0);
        assertEq(auctionToken.balanceOf(emitter), 500_000 ether);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);
        assertEq(uint256(info.state), uint256(SaleState.FAILED));

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 1_000_000 ether);
        assertEq(auctionToken.balanceOf(bidder), 0);
    }

    function testFeesDontAffectExistingCrowdSale() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        assertEq(crowdSale.getSaleInfo(saleId).feeBp, 0);

        vm.startPrank(deployer);
        crowdSale.setCurrentFeesBp(2500);
        assertEq(crowdSale.getSaleInfo(saleId).feeBp, 0);
        vm.stopPrank();
    }

    function testTwoBiddersMeetExactly() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 50_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        (uint256 auctionTokens, uint256 refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 100_000 ether);
        assertEq(refunds, 0);
        //a bidder can call this as often as they want, but they won't get anything
        (auctionTokens, refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 0);
        assertEq(refunds, 0);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 300_000 ether);
        assertEq(auctionToken.balanceOf(bidder2), 100_000 ether);
    }

    function testSingleRefundsOnOvershoot() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 1_000_000 ether, "");
        vm.stopPrank();
        assertEq(biddingToken.balanceOf(bidder), 0);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        (uint256 auctionTokens, uint256 refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 400_000 ether);
        assertEq(refunds, 800_000 ether);
        //a bidder can call this as often as they want, but they won't get anything
        (auctionTokens, refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 0);
        assertEq(refunds, 0);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 400_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 800_000 ether);
    }

    function testOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 400_000 ether, "");
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
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        (uint256 auctionTokens, uint256 refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 100_000 ether);
        assertEq(refunds, 150_000 ether);
        //a bidder can call this as often as they want, but they won't get anything
        (auctionTokens, refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 0);
        assertEq(refunds, 0);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        (auctionTokens, refunds) = crowdSale.claim(saleId, "");
        assertEq(auctionTokens, 0);
        assertEq(refunds, 0);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 300_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 850_000 ether);

        assertEq(auctionToken.balanceOf(bidder2), 100_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 950_000 ether);

        crowdSale.claimResults(saleId);

        assertEq(auctionToken.balanceOf(address(crowdSale)), 0);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnevenOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 380_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 450_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 230_000 ether, "");
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
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        crowdSale.claim(saleId, ""); //just to ensure this doesn't have any effect
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 230188679245283018800000);
        assertEq(biddingToken.balanceOf(bidder), 884905660377358490420000);

        assertEq(auctionToken.balanceOf(bidder2), 169811320754716980800000);
        assertEq(biddingToken.balanceOf(bidder2), 915094339622641508720000);

        crowdSale.claimResults(saleId);

        //some dust is left on the table
        //these are 0.0000000000004 tokens at 18 decimals
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 860_000);
    }

    function testFeesAreTakenOnSettlement() public {
        vm.startPrank(deployer);
        crowdSale.setCurrentFeesBp(1000);
        vm.stopPrank();

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 150_000 ether, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours + 1);

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        assertEq(biddingToken.balanceOf(emitter), 0);
        crowdSale.claimResults(saleId);

        //fees were taken
        assertEq(biddingToken.balanceOf(emitter), 180_000 ether);
        assertEq(biddingToken.balanceOf(deployer), 20_000 ether);

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 200_000 ether);
        assertEq(auctionToken.balanceOf(bidder2), 200_000 ether);

        //fees don't affect refunds
        assertEq(biddingToken.balanceOf(bidder), 900_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 900_000 ether);
    }

    //todo check how dangerous this is
    function testTinyBidsDustEffect() public {
        vm.startPrank(deployer);
        crowdSale.setCurrentFeesBp(1000);
        vm.stopPrank();

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether - 1, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 2, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 2 hours + 1);

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        assertEq(biddingToken.balanceOf(emitter), 180_000 ether);

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), 399999999999999999600000);
        assertEq(auctionToken.balanceOf(bidder2), 0);

        assertEq(biddingToken.balanceOf(bidder), 800000000000000000000001);
        assertEq(biddingToken.balanceOf(bidder2), 999999999999999999999998);

        //dust stays on the contract
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 1);
    }
}
