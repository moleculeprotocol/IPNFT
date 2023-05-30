// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, SaleState, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";
import { VestedCrowdSale, VestingConfig, UnmanageableVestingContract, InvalidDuration } from "../src/crowdsale/VestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
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

        _vestingConfig = VestingConfig({ vestingContract: TokenVesting(address(0)), cliff: 60 days });
    }

    function testVestedCrowdSalesConformsToTokenVestingRules() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        vm.expectRevert(InvalidDuration.selector);
        crowdSale.startSale(_sale, TokenVesting(address(0)), 5 days);

        vm.expectRevert(InvalidDuration.selector);
        crowdSale.startSale(_sale, TokenVesting(address(0)), 1 days + 50 * (365 days));

        vm.stopPrank();
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        uint256 saleId = crowdSale.startSale(_sale, TokenVesting(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);

        vm.startPrank(bidder);
        vm.warp(_sale.closingTime + 10 days);
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionToken.balanceOf(bidder), 0);

        vm.warp(_sale.closingTime + 60 days);
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
        vm.stopPrank();
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, TokenVesting(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 150_000 ether);
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
        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
    }

    function testBringYourOwnVestingContract() public {
        vm.startPrank(anyone);
        TokenVesting vestingContract = new TokenVesting(auctionToken, "Selfmade vMOL", "vMOLE");
        bytes32 ROLE_CREATE_SCHEDULE = vestingContract.ROLE_CREATE_SCHEDULE();
        vm.stopPrank();

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        vm.expectRevert(UnmanageableVestingContract.selector);
        crowdSale.startSale(_sale, vestingContract, 60 days);

        vm.expectRevert(
            "AccessControl: account 0x5b82c2eec3e5e731e21c7fdea9c4e74c49b74093 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        vestingContract.grantRole(ROLE_CREATE_SCHEDULE, address(crowdSale));
        vm.stopPrank();

        vm.startPrank(anyone);
        vestingContract.grantRole(ROLE_CREATE_SCHEDULE, address(crowdSale));
        vm.stopPrank();

        vm.startPrank(emitter);
        uint256 saleId = crowdSale.startSale(_sale, vestingContract, 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);

        vm.warp(_sale.closingTime + 60 days);

        vm.startPrank(bidder); //actually, only the vesting subject may call that.
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
        vm.stopPrank();
    }

    function testClaimLongAfterVestingPeriod() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.closingTime = uint64(block.timestamp + 7 days);

        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, TokenVesting(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.warp(block.timestamp + 4440 days);
        vm.startPrank(bidder);
        crowdSale.claim(saleId);

        //skips the vesting contract
        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);

        assertEq(auctionToken.balanceOf(bidder), 400_000 ether);

        vm.stopPrank();
    }
}
