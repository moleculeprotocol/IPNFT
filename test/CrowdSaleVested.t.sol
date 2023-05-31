// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, SaleState, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";
import { VestedCrowdSale, VestingConfig, UnmanageableVestingContract } from "../src/crowdsale/VestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken, StillLocked } from "../src/TimelockedToken.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

contract CrowdSaleVestedTest is Test {
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    VestedCrowdSale internal crowdSale;
    VestingConfig internal _vestingConfig;

    function setUp() public {
        crowdSale = new VestedCrowdSale();
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

        _vestingConfig = VestingConfig({ vestingContract: TimelockedToken(address(0)), cliff: 60 days });
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        uint256 saleId = crowdSale.startSale(_sale, TimelockedToken(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        vm.recordLogs();
        crowdSale.claim(saleId);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[1].topics[0], keccak256("ScheduleCreated(bytes32,address,address,uint256,uint64)"));
        bytes32 scheduleId = entries[1].topics[1];
        vm.stopPrank();

        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);

        vm.startPrank(bidder);
        vm.warp(_sale.closingTime + 10 days);
        vm.expectRevert(StillLocked.selector);
        auctionTokenVesting.release(scheduleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionToken.balanceOf(bidder), 0);

        vm.warp(_sale.closingTime + 60 days);
        auctionTokenVesting.release(scheduleId);
        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
        vm.stopPrank();
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, TimelockedToken(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), 0);
        assertEq(auctionToken.balanceOf(emitter), 500_000 ether);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);
        assertEq(uint256(info.state), uint256(SaleState.FAILED));

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 1_000_000 ether);
        assertEq(auctionToken.balanceOf(bidder), 0);
        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
    }

    function testBringYourOwnVestingContract() public {
        vm.startPrank(anyone);
        TimelockedToken vestingContract = new TimelockedToken();
        vestingContract.initialize(auctionToken);
        vm.stopPrank();

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        vm.startPrank(emitter);
        uint256 saleId = crowdSale.startSale(_sale, vestingContract, 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        vm.recordLogs();
        crowdSale.claim(saleId);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[1].topics[0], keccak256("ScheduleCreated(bytes32,address,address,uint256,uint64)"));
        assertEq(bidder, address(uint160(uint256((entries[1].topics[2])))));
        bytes32 scheduleId = entries[1].topics[1];
        vm.stopPrank();

        assertEq(vestingContract.balanceOf(bidder), _sale.salesAmount);

        vm.warp(_sale.closingTime + 60 days);
        vm.startPrank(anyone);
        vestingContract.release(scheduleId);
        vm.stopPrank();

        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
        assertEq(vestingContract.balanceOf(bidder), 0);
    }

    function testClaimLongAfterVestingPeriod() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.closingTime = uint64(block.timestamp + 7 days);

        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, TimelockedToken(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.warp(block.timestamp + 4440 days);
        vm.startPrank(bidder);
        crowdSale.claim(saleId);

        //skips the vesting contract
        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);

        assertEq(auctionToken.balanceOf(bidder), 400_000 ether);

        vm.stopPrank();
    }
}
