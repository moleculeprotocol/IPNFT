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

        bidder added 600_000$ (keeps 400_000$)
        this is 3/4 of all bids
        bidder receives 3/4 of 400_000 = 300_000 FAM
        bidder is refunded  3/4 of 600_000 = 450_000$
        bidder contributed 600_000$ - 450_000$ = $150_000 to the funding
        bidder's final $ balance = 400_000 + 450_000 = 850_000$

        bidder2 added 200_000$ (keeps 800_000$)
        this is 1/4 of all bids
        bidder2 receives 1/4 of 400_000 = 100_000 FAM
        bidder2 is refunded 1/4 of 600_000 = 150_000$
        bidder2 contributed 200_000$ - 150_000$ = $50_000 to the funding
        bidder2's final $ balance = 800_000 + 150_000 = 950_000$

        > together bidder1 and bidder2 staked 600_000 + 200_000 = 800_000 DAO at dao/$ price of 1
        > *all* stakes are paid back. The "active" ratio is paid as vested, the "inactive" simply refunded
        all stakers staked 800_000 dao

        bidder staked 600_000 dao at dao/bid price of 1
        bidder receives 3/4*600_000  = 450_000  vDAO 
        bidder is refunded the rest (600_000 - 450_000 = 150_000) DAO 
        bidder stakes returned =  450_000 + 150_000 = 600_000 DAO

        bidder2 staked 200_000 dao at dao/bid price of 1
        bidder2 receives 1/4*200_000 = 50_000  vDAO 
        bidder2 is refunded the rest (200_000 - 50_000 = 150_000) DAO
        bidder stakes returned =  50_000 + 150_000 = 200_000 DAO
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
        assertEq(vestedDao.balanceOf(bidder), 450_000 ether);
        assertEq(daoToken.balanceOf(bidder), 550_000 ether);

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
        (,, uint256 price, uint256 stakeTotal) = crowdSale.salesStaking(saleId);
        assertEq(stakeTotal, 1_060_000 ether);

        assertEq(crowdSale.stakesOf(saleId, bidder), 610_000 ether);
        assertEq(crowdSale.stakesOf(saleId, bidder2), 450_000 ether);

        /*
        bidder and bidder2 have 1mn$ each

        400_000 auction tokens are sold
        200_000$ are requested
        1_060_000$ are bid in total
        860_000$ are overshot

        bidder added 610_000$ (keeps 390_000$)
        this is x = 0.575471  of all bids
        bidder receives x * 400_000 = 230188.4 FAM
        bidder is refunded  x of 860_000 = $494905.660377
        bidder contributed (610_000 - 494905 = 115_095$) to the funding
        bidder's final $ balance = 390_000 + 494905 = 884905$
        
        bidder2 added 450_000$ (keeps 550_000$)
        this is y = 0.424528 of all bids
        bidder2 receives y * 400_000 = 169811.3208 FAM
        bidder2 is refunded y of 860_000 = $365094.33972
        bidder contributed (450_000 - 365094 = 84_906$) to the funding
        bidder2's final $ balance = 550_000 + 365094 = 915094$

        > together bidder1 and bidder2 staked 610_000 + 450_000 = 1_060_000 dao tokens at dao/bid price of 1
        > *all* stakes are paid back. The "active" ratio is paid as vested, the "inactive" simply refunded
        
        all stakers staked 1_060_000 dao
        bidder staked 610_000 dao at dao/bid price of 1
        bidder receives x*610_000  = 351037.735  vdao 
        bidder is refunded the rest (610_000 - 351037.31 = 258963) dao 
        bidder stakes returned =  351037 + 258963 = 610_000 dao

        bidder2 staked 450_000 dao at dao/bid price of 1
        bidder2 receives y*450_000 = 191037.6  vdao 
        bidder2 is refunded the rest (450_000 - 191037.6 = 258963) dao
        bidder stakes returned =  191037 + 258963 = 450_000 dao
        
        in total:
        total FAM sold 230188.4 + 169811.3208 = 399_999.7208
        total $ refunded 860_000
        total stakes returned = 450_000 + 610_000 = 1_060_000 (all)
        */

        vm.startPrank(anyone);
        crowdSale.settle(saleId);
        vm.stopPrank();

        uint256 oldDaoBalanceBidder = daoToken.balanceOf(bidder);
        uint256 oldDaoBalanceBidder2 = daoToken.balanceOf(bidder2);

        vm.startPrank(bidder);
        crowdSale.claim(saleId);
        vm.stopPrank();

        vm.startPrank(bidder2);
        crowdSale.claim(saleId);
        vm.stopPrank();

        (TokenVesting auctionTokenVesting,,) = crowdSale.salesVesting(saleId);
        assertEq(auctionTokenVesting.balanceOf(bidder), 230188679245283018800000);
        assertEq(auctionTokenVesting.balanceOf(bidder2), 169811320754716980800000);

        //todo: the direct returns are equal?!
        assertEq(daoToken.balanceOf(bidder) - oldDaoBalanceBidder, 258962264150943396330000);
        assertEq(daoToken.balanceOf(bidder2) - oldDaoBalanceBidder2, 258962264150943396600000);

        assertEq(daoToken.balanceOf(bidder) - oldDaoBalanceBidder + vestedDao.balanceOf(bidder), 610_000 ether);
        assertEq(daoToken.balanceOf(bidder2) - oldDaoBalanceBidder2 + vestedDao.balanceOf(bidder2), 450_000 ether);

        //some dust is left on the table
        //these are 0.0000000000004 tokens at 18 decimals
        assertEq(auctionToken.balanceOf(address(crowdSale)), 400_000);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 860_000);
        assertEq(daoToken.balanceOf(address(crowdSale)), 0);
    }
}
