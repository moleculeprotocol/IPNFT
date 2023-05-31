// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo, SaleState, BadDecimals } from "../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale, IncompatibleVestingContract, BadPrice } from "../src/crowdsale/StakedVestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../src/TimelockedToken.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
//import { BioPriceFeed, IPriceFeedConsumer } from "../src/BioPriceFeed.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

contract CrowdSaleVestedStakedTest is Test {
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

    function setUp() public {
        vm.startPrank(deployer);

        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");
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
        biddingToken.mint(bidder, 1_000_000 ether);
        daoToken.mint(bidder, 1_000_000 ether);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        daoToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        biddingToken.mint(bidder2, 1_000_000 ether);
        daoToken.mint(bidder2, 1_000_000 ether);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        daoToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();
    }

    function testStakeVestedCrowdSalesBadParameters() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        vm.expectRevert(); //cannot call .decimals() on 0x0
        crowdSale.startSale(_sale, IERC20Metadata(address(0)), TokenVesting(address(0)), 0, TimelockedToken(address(0)), 60 days);

        vm.expectRevert();
        crowdSale.startSale(_sale, daoToken, TokenVesting(address(0)), 0, TimelockedToken(address(0)), 60 days);

        TokenVesting wrongStakeVestingContract = new TokenVesting(auctionToken, "vested mol", "vmol");
        wrongStakeVestingContract.grantRole(wrongStakeVestingContract.ROLE_CREATE_SCHEDULE(), address(crowdSale));

        vm.expectRevert(IncompatibleVestingContract.selector);
        crowdSale.startSale(_sale, daoToken, wrongStakeVestingContract, 0, TimelockedToken(address(0)), 60 days);

        vm.expectRevert(BadPrice.selector);
        crowdSale.startSale(_sale, daoToken, vestedDao, 0, TimelockedToken(address(0)), 60 days);

        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1, TimelockedToken(address(0)), 60 days);

        (,,, uint256 stakeTotal) = crowdSale.salesStaking(saleId);
        //the total stakes are set to 0 upon initialization
        assertEq(stakeTotal, 0);
    }

    function testSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);

        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, TimelockedToken(address(0)), 60 days);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether, "");
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 800_000 ether);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 200_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 200_000 ether);

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

        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 200_000 ether);
    }

    function testOverbiddingAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, TimelockedToken(address(0)), 60 days);

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

        assertEq(biddingToken.balanceOf(bidder), 400_000 ether);
        assertEq(daoToken.balanceOf(bidder), 400_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 800_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 800_000 ether);

        /*
        bidder and bidder2 have 1mn$ & 1mn DAO each

        400_000 auction tokens are sold
        200_000$ are requested
        800_000$ are bid in total
        600_000$ are surplus

        bidder added 600_000$ (and still has 400_000$)
        this is 3/4 of all bids
        bidder receives 3/4 of 400_000 = 300_000 FAM
        bidder is refunded  3/4 of 600_000 = 450_000$
        bidder contributed 600_000$ - 450_000$ = $150_000 to the funding

        bidder staked 600_000 dao at dao/bid price of 1
        bidder is refunded 450_000 DAO (1DAO/1$ * 450_000$ refunds)
        bidder gets (all staked - refund) vDAO (600_000-450_000) = 150_000 vDAO
        token amt of bidder stakes returned =  450_000DAO + 150_000vDAO = 600_000
        bidder's final $ balance = 400_000 + 450_000 = 850_000$

        bidder2 added 200_000$ (and still has 800_000$)
        this is 1/4 of all bids
        bidder2 receives 1/4 of 400_000 = 100_000 FAM
        bidder2 is refunded 1/4 of 600_000 = 150_000$
        bidder2 contributed 200_000$ - 150_000$ = $50_000 to the funding

        bidder2 staked 200_000 DAO at dao/bid price of 1
        bidder2 is refunded 150_000 DAO (1DAO/1$ * 150_000$)
        bidder2 gets (all staked - refund) vDAO (200_000-150_000) 50_000 vDAO
        token amt of bidder stakes returned =  150_000DAO + 50_000vDAO = 200_000
        bidder2's final $ balance = 800_000 + 150_000 = 950_000$

        -- And now with varying prices (same $ amounts)
        -- auction is settled at a price of 1.5DAO/1$

        bidder staked 1_200_000 dao at dao/bid price of 2 ($600_000 * 2)
        bidder is refunded 675_000 DAO (1.5DAO/1$ * $450_000)
        bidder received (all staked - refund) vDAO (1_200_000-675_000) = 525_000 vDAO
        token amt of bidder stakes returned =  675_000DAO + 525_000vDAO = 1_200_000

        bidder2 staked 600_000 dao at dao/bid price of 3 ($200_000 * 3)
        bidder2 is refunded 225_000 DAO (1.5DAO/1$ * $150_000)
        bidder2 gets (all staked - refund) vDAO (600_000-225_000) 375_000 vDAO
        token amt of bidder stakes returned =  225_000DAO + 375_000vDAO = 600_000

        */
        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        (uint256 zeroTokens, uint256 zeroRefunds) = crowdSale.claim(saleId);
        assertEq(zeroRefunds * zeroTokens, 0);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2); //tries to "attack" by claiming once again
        (zeroTokens, zeroRefunds) = crowdSale.claim(saleId);
        assertEq(zeroRefunds * zeroTokens, 0);
        vm.stopPrank();

        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 300_000 ether);
        assertEq(biddingToken.balanceOf(bidder), 850_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 150_000 ether);
        assertEq(daoToken.balanceOf(bidder), 850_000 ether);

        assertEq(auctionTokenVesting.balanceOf(bidder2), 100_000 ether);
        assertEq(biddingToken.balanceOf(bidder2), 950_000 ether);
        assertEq(vestedDao.balanceOf(bidder2), 50_000 ether);
        assertEq(daoToken.balanceOf(bidder2), 950_000 ether);

        assertEq(auctionToken.balanceOf(address(crowdSale)), 0);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 0);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnevenOverbiddingAndPriceAndRefunds() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        // 1 DAO = 4 $
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 25e16, TimelockedToken(address(0)), 60 days);

        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 380_000 ether, "");
        assertEq(daoToken.balanceOf(address(crowdSale)), 95_000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 450_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 230_000 ether, "");
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

        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 230188679245283018800000);
        assertEq(auctionTokenVesting.balanceOf(bidder2), 169811320754716980800000);

        assertEq(vestedDao.balanceOf(bidder), 28773.584905660377395 ether);
        assertEq(vestedDao.balanceOf(bidder2), 21226.41509433962282 ether);

        assertEq(daoToken.balanceOf(bidder) + vestedDao.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder2) + vestedDao.balanceOf(bidder2), 1_000_000 ether);

        // //some dust is left on the table
        // //these are 0.0000000000004 tokens at 18 decimals
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 860_000);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }

    function testUnsuccessfulSaleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        auctionToken.approve(address(crowdSale), 400_000 ether);

        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 25e16, TimelockedToken(address(0)), 60 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 50_000 ether, "");
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.placeBid(saleId, 50_000 ether, "");
        vm.stopPrank();

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        vm.stopPrank();

        //when settling a failed sale, the auctioneer receives back all their auction tokens
        assertEq(auctionToken.balanceOf(emitter), 500_000 ether);
        assertEq(biddingToken.balanceOf(emitter), 0);

        SaleInfo memory info = crowdSale.getSaleInfo(saleId);
        assertEq(info.surplus, 0);
        assertEq(uint256(info.state), uint256(SaleState.FAILED));

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        //after claiming a bid on a failed sale, the bidder
        //receives all their bids and stakes back
        assertEq(biddingToken.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder), 1_000_000 ether);

        assertEq(auctionToken.balanceOf(bidder), 0);
        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
    }

    function testClaimLongAfterVestingPeriod() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
        _sale.closingTime = uint64(block.timestamp + 7 days);
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, TimelockedToken(address(0)), 60 days);
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

        (TimelockedToken auctionTokenVesting,) = crowdSale.salesVesting(saleId);

        assertEq(auctionTokenVesting.balanceOf(bidder), 0);
        assertEq(auctionToken.balanceOf(bidder), 400_000 ether);

        assertEq(vestedDao.balanceOf(bidder), 0);
        assertEq(daoToken.balanceOf(bidder), 1_000_000 ether);
        vm.stopPrank();
    }
}
