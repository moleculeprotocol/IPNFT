// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, SaleState, BadDecimals } from "../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale, BadPrice, StakingInfo } from "../src/crowdsale/StakedLockingCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../src/TimelockedToken.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

/**
 * @notice tests support for ERC20 with 6 decimals
 */
contract CrowdSaleWithNonStandardERC20Test is Test {
    address deployer = makeAddr("chucknorris");
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    FakeERC20 internal daoToken;

    //this typically is the DAO's general vesting contract
    TokenVesting internal vestedDao;

    //BioPriceFeed internal priceFeed;

    StakedLockingCrowdSale internal crowdSale;

    function setUp() public {
        vm.startPrank(deployer);

        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");
        biddingToken.setDecimals(6);

        daoToken = new FakeERC20("DAO token", "DAO");

        // BioPriceFeed internal priceFeed = new BioPriceFeed();
        // // 1=1 is the trivial case
        // priceFeed.signal(address(biddingToken), address(daoToken), 1e18);

        crowdSale = new StakedLockingCrowdSale();

        auctionToken.mint(emitter, 500_000 ether);

        vestedDao = new TokenVesting(
            daoToken,
            string(abi.encodePacked("Vested ", daoToken.name())),
            string(abi.encodePacked("v", daoToken.symbol()))
        );

        vestedDao.grantRole(vestedDao.ROLE_CREATE_SCHEDULE(), address(crowdSale));
        crowdSale.registerVestingContract(vestedDao);
        vm.stopPrank();
        vm.startPrank(bidder);
        biddingToken.mint(bidder, 1_000_000e6);
        daoToken.mint(bidder, 1_000_000 ether);
        biddingToken.approve(address(crowdSale), 1_000_000e6);
        daoToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        biddingToken.mint(bidder2, 1_000_000e6);
        daoToken.mint(bidder2, 1_000_000 ether);
        biddingToken.approve(address(crowdSale), 1_000_000e6);
        daoToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000e6, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 800_000e6);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 200_000e6);

        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 200_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();
        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 200_000 ether);
    }

    function testOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000e6, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 200_000e6, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 400_000e6, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 400_000e6);
        assertEq(daoToken.balanceOf(bidder), 400_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 800_000e6);
        assertEq(daoToken.balanceOf(address(crowdSale)), 800_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));

        assertEq(auctionTokenVesting.balanceOf(bidder), 300_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 850_000e6);
        assertEq(vestedDao.balanceOf(bidder), 150_000 ether);
        assertEq(daoToken.balanceOf(bidder), 850_000 ether);

        assertEq(auctionTokenVesting.balanceOf(bidder2), 100_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 950_000e6);
        assertEq(vestedDao.balanceOf(bidder2), 50_000 ether);
        assertEq(daoToken.balanceOf(bidder2), 950_000 ether);

        assertEq(auctionToken.balanceOf(address(crowdSale)), 0);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 0);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnevenOverbiddingAndPriceAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        // 1 DAO = 4 $ <=> 1$ = 0.25 DAO, the price is always expressed as 1e18 decimal
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 25e16, 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 380_000e6, "");
        assertEq(daoToken.balanceOf(address(crowdSale)), 95_000 ether);
        assertEq(crowdSale.stakesOf(saleId, bidder), 95_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 450_000e6, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 230_000e6, "");
        vm.stopPrank();

        //stakes have been placed.
        assertEq(daoToken.balanceOf(bidder), 847_500 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 265_000 ether);

        assertEq(crowdSale.stakesOf(saleId, bidder), 152_500 ether);
        assertEq(crowdSale.stakesOf(saleId, bidder2), 112_500 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));

        assertEq(auctionTokenVesting.balanceOf(bidder), 230188679245283018800000);
        assertEq(auctionTokenVesting.balanceOf(bidder2), 169811320754716980800000);

        assertEq(vestedDao.balanceOf(bidder), 28773.58490575 ether);
        assertEq(vestedDao.balanceOf(bidder2), 21226.4150945 ether);

        assertEq(daoToken.balanceOf(bidder) + vestedDao.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder2) + vestedDao.balanceOf(bidder2), 1_000_000 ether);

        //some dust is left on the table
        crowdSale.claimResults(saleId);
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 1);
        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        //0.25 DAO (18dec) / USDC (6dec)
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 25e16, 60 days);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 50_000e6, "");
        assertEq(daoToken.balanceOf(address(crowdSale)), 12_500 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 50_000e6, "");
        assertEq(daoToken.balanceOf(address(crowdSale)), 25_000 ether);
        vm.stopPrank();

        vm.startPrank(anyone);
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

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 1_000_000e6);
        assertEq(biddingToken.balanceOf(bidder2), 1_000_000e6);
        assertEq(auctionToken.balanceOf(bidder), 0);
        assertEq(daoToken.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder2), 1_000_000 ether);
        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));
        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
    }

    //todo: write dynamic decimals & invariant tests
    function testWith2Decimals() public {
        biddingToken = new FakeERC20("Euro token with 2 decimals", "EURS");
        biddingToken.setDecimals(2);
        biddingToken.mint(bidder, 100_000e2);
        biddingToken.mint(bidder2, 100_000e2);

        vm.startPrank(bidder);
        biddingToken.approve(address(crowdSale), 100_000e2);
        daoToken.approve(address(crowdSale), 240_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        biddingToken.approve(address(crowdSale), 100_000e2);
        daoToken.approve(address(crowdSale), 80_000 ether);
        vm.stopPrank();

        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 50_000e2;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 4e18, 7 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 20_000e2, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 20_000e2, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 40_000e2, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 40_000e2);
        assertEq(daoToken.balanceOf(bidder), 760_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 80_000e2);
        assertEq(daoToken.balanceOf(address(crowdSale)), 320_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId, "");
        vm.stopPrank();

        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));
        assertEq(auctionTokenVesting.balanceOf(bidder), 300_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 62_500e2);
        assertEq(vestedDao.balanceOf(bidder), 150_000 ether);
        assertEq(daoToken.balanceOf(bidder), 850_000 ether);

        assertEq(auctionTokenVesting.balanceOf(bidder2), 100_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 87_500e2);
        assertEq(vestedDao.balanceOf(bidder2), 50_000 ether);
        assertEq(daoToken.balanceOf(bidder2), 950_000 ether);
        crowdSale.claimResults(saleId);
        assertEq(auctionToken.balanceOf(address(crowdSale)), 0);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 0);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }
}
