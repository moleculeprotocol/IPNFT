// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale, StakingConfig } from "../src/crowdsale/StakedVestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { FakeERC20 } from "./helpers/FakeERC20.sol";

contract CrowdSaleVestedStakedTest is Test {
    address emitter = makeAddr("emitter");
    address bidder = makeAddr("bidder");
    address bidder2 = makeAddr("bidder2");

    address anyone = makeAddr("anyone");

    FakeERC20 internal auctionToken;
    FakeERC20 internal biddingToken;
    FakeERC20 internal daoToken;

    //this typically is the DAO's general vesting contract
    TokenVesting internal vestedDao;

    StakedVestedCrowdSale internal crowdSale;

    function setUp() public {
        crowdSale = new StakedVestedCrowdSale();
        auctionToken = new FakeERC20("Fractionalized IPNFT","FAM");
        biddingToken = new FakeERC20("USD token", "USDC");
        daoToken = new FakeERC20("DAO token", "DAO");

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

    function makeSale() internal returns (Sale memory sale) {
        return Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20(address(biddingToken)),
            fundingGoal: 200_000 ether,
            salesAmount: 400_000 ether,
            closingTime: 0
        });
    }

    function testSettlementAndSimpleClaims() public {
        uint256 genesis = block.timestamp;

        vm.startPrank(emitter);
        Sale memory _sale = makeSale();

        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days, 365 days);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.placeBid(saleId, 200_000 ether);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 800_000 ether);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 200_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 200_000 ether);

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
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 200_000 ether);
    }

    function testOverbiddingAndRefunds() public {
        uint256 genesis = block.timestamp;

        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days, 365 days);
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
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,,) = crowdSale.salesVesting(saleId);

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

    function testUnevenOverbiddingAndRefunds() public {
        uint256 genesis = block.timestamp;

        vm.startPrank(emitter);
        Sale memory _sale = makeSale();
        auctionToken.approve(address(crowdSale), 400_000 ether);
        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days, 365 days);
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

        //stakes have been placed.
        assertEq(daoToken.balanceOf(bidder), 390_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 1_060_000 ether);
        (,,,, uint256 stakeTotal) = crowdSale.salesStaking(saleId);
        assertEq(stakeTotal, 1_060_000 ether);

        assertEq(crowdSale.stakesOf(saleId, bidder), 610_000 ether);
        assertEq(crowdSale.stakesOf(saleId, bidder2), 450_000 ether);

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 230188679245283018800000);
        assertEq(auctionTokenVesting.balanceOf(bidder2), 169811320754716980800000);

        assertEq(daoToken.balanceOf(bidder), 884905660377358490420000);
        assertEq(daoToken.balanceOf(bidder2), 915094339622641508720000);

        assertEq(daoToken.balanceOf(bidder) + vestedDao.balanceOf(bidder), 1_000_000 ether);
        assertEq(daoToken.balanceOf(bidder2) + vestedDao.balanceOf(bidder2), 1_000_000 ether);

        // //some dust is left on the table
        // //these are 0.0000000000004 tokens at 18 decimals
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 860_000);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }
}
