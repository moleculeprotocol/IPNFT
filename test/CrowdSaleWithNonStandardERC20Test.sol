// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, SaleState, BadDecimals } from "../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale, StakingConfig, IncompatibleVestingContract, BadPrice } from "../src/crowdsale/StakedVestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { FakeERC20 } from "./helpers/FakeERC20.sol";
//import { BioPriceFeed, IPriceFeedConsumer } from "../src/BioPriceFeed.sol";
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

    StakedVestedCrowdSale internal crowdSale;
    VestingConfig internal _vestingConfig;
    StakingConfig internal _stakingConfig;

    function setUp() public {
        vm.startPrank(deployer);

        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");
        biddingToken.setDecimals(6);

        daoToken = new FakeERC20("DAO token", "DAO");

        // BioPriceFeed internal priceFeed = new BioPriceFeed();
        // // 1=1 is the trivial case
        // priceFeed.signal(address(biddingToken), address(daoToken), 1e18);

        crowdSale = new StakedVestedCrowdSale();
        vm.stopPrank();

        auctionToken.mint(emitter, 500_000 ether);

        vestedDao = new TokenVesting(
            daoToken,
            string(abi.encodePacked("Vested ", daoToken.name())),
            string(abi.encodePacked("v", daoToken.symbol()))
        );

        vestedDao.grantRole(vestedDao.ROLE_CREATE_SCHEDULE(), address(crowdSale));

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

        _vestingConfig = VestingConfig({ vestingContract: TokenVesting(address(0)), cliff: 60 days });
        _stakingConfig = StakingConfig({ stakedToken: daoToken, stakesVestingContract: vestedDao, wadFixedDaoPerBidPrice: 1e18, stakeTotal: 0 });
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);

        uint256 saleId = crowdSale.startSale(_sale, _stakingConfig, _vestingConfig);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000e6);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 800_000e6);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 200_000e6);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);

        assertEq(daoToken.balanceOf(address(crowdSale)), 200_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);
        SaleInfo memory info = crowdSale.saleInfo(saleId);
        assertEq(info.surplus, 0);

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 200_000 ether);
    }

    function testOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, _stakingConfig, _vestingConfig);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000e6);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 200_000e6);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 400_000e6);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 400_000e6);
        assertEq(daoToken.balanceOf(bidder), 400_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 800_000e6);
        assertEq(daoToken.balanceOf(address(crowdSale)), 800_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);

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
        // 1 DAO = 4 $
        _stakingConfig.wadFixedDaoPerBidPrice = 25e16;
        uint256 saleId = crowdSale.startSale(_sale, _stakingConfig, _vestingConfig);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 380_000e6);
        assertEq(daoToken.balanceOf(address(crowdSale)), 95_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 450_000e6);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 230_000e6);
        vm.stopPrank();

        //stakes have been placed.
        assertEq(daoToken.balanceOf(bidder), 847_500 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 265_000 ether);
        (,,, uint256 stakeTotal) = crowdSale.salesStaking(saleId);
        assertEq(stakeTotal, 265_000 ether);

        assertEq(crowdSale.stakesOf(saleId, bidder), 152_500 ether);
        assertEq(crowdSale.stakesOf(saleId, bidder2), 112_500 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 230188679244000000000000);
        assertEq(auctionTokenVesting.balanceOf(bidder2), 169811320754000000000000);

        assertEq(vestedDao.balanceOf(bidder), 28773.5849065 ether);
        assertEq(vestedDao.balanceOf(bidder2), 21226.41509475 ether);

        assertEq(daoToken.balanceOf(bidder) + vestedDao.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder2) + vestedDao.balanceOf(bidder2), 1_000_000 ether);

        //some dust is left on the table
        assertEq(auctionToken.balanceOf(address(crowdSale)), 0.000002 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 5);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.fundingGoal = 200_000e6;
        auctionToken.approve(address(crowdSale), 400_000 ether);
        _stakingConfig.wadFixedDaoPerBidPrice = 25e16;
        uint256 saleId = crowdSale.startSale(_sale, _stakingConfig, _vestingConfig);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 50_000e6);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 50_000e6);
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), 0);
        assertEq(auctionToken.balanceOf(emitter), 500_000 ether);
        SaleInfo memory info = crowdSale.saleInfo(saleId);
        assertEq(info.surplus, 0);
        assertEq(uint256(info.state), uint256(SaleState.FAILED));

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 1_000_000e6);
        assertEq(auctionToken.balanceOf(bidder), 0);
        (TokenVesting auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
    }
}