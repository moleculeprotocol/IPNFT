// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";
import { VestedCrowdSale, VestingConfig } from "../src/crowdsale/VestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { FakeERC20 } from "./helpers/FakeERC20.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

contract CrowdSaleVestedTest is Test {
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    VestedCrowdSale internal crowdSale;

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
    }

    function testSettlementAndSimpleClaims() public {
        uint256 genesis = block.timestamp;

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, 60 days, 365 days);
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

        (TokenVesting auctionTokenVesting,,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);

        vm.startPrank(bidder);
        vm.warp(genesis + 10 days);
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionToken.balanceOf(bidder), 0);

        vm.warp(genesis + 60 days);
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertTrue(auctionToken.balanceOf(bidder) > 65_000 ether);

        vm.warp(genesis + 366 days);
        auctionTokenVesting.releaseAvailableTokensForHolder(bidder);
        assertEq(auctionToken.balanceOf(bidder), _sale.salesAmount);
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
        vm.stopPrank();
    }
}
