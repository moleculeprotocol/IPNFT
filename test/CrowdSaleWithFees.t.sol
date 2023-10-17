// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;

// import "forge-std/Test.sol";
// import { CrowdSaleWithFees } from "../src/crowdsale/CrowdSaleWithFees.sol";
// import { Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";
// import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
// import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";

// contract CrowdSaleWithFeesTest is Test {
//     CrowdSaleWithFees crowdSaleWithFees;
//     FakeERC20 internal auctionToken;
//     FakeERC20 internal biddingToken;
//     uint256 percentageFees = 10;

//     address emitter = makeAddr("emitter");
//     address bidder = makeAddr("bidder");
//     address anyone = makeAddr("anyone");
//     address crowdSalesOwner = makeAddr("crowdSalesOwner");

//     // TEST HAPPY PATHS NOW

//     function setUp() public {
//         vm.startPrank(crowdSalesOwner);
//         crowdSaleWithFees = new CrowdSaleWithFees(percentageFees);
//         vm.stopPrank();
//         auctionToken = new FakeERC20("IPTOKENS","IPT");
//         biddingToken = new FakeERC20("USD token", "USDC");

//         auctionToken.mint(emitter, 500_000 ether);
//         biddingToken.mint(bidder, 1_000_000 ether);

//         vm.startPrank(bidder);
//         biddingToken.approve(address(crowdSaleWithFees), 1_000_000 ether);
//         vm.stopPrank();
//     }

//     function testSetUp() public {
//         assertEq(crowdSaleWithFees.getFees(), 10);
//         assertEq(crowdSaleWithFees.owner(), crowdSalesOwner);
//     }

//     function testStartSale() public {
//         Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
//         vm.startPrank(emitter);
//         auctionToken.approve(address(crowdSaleWithFees), 400_000 ether);
//         uint256 saleId = crowdSaleWithFees.startSale(_sale);
//         assertEq(crowdSaleWithFees.getCrowdSaleFees(saleId), 10);
//         vm.stopPrank();
//     }

//     function testUpdateFees() public {
//         Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
//         vm.startPrank(emitter);
//         auctionToken.approve(address(crowdSaleWithFees), 400_000 ether);
//         uint256 saleId = crowdSaleWithFees.startSale(_sale);
//         assertEq(crowdSaleWithFees.getCrowdSaleFees(saleId), 10);
//         vm.stopPrank();
//         vm.startPrank(anyone);
//         vm.expectRevert("Ownable: caller is not the owner");
//         crowdSaleWithFees.updateCrowdSaleFees(20);
//         vm.stopPrank();

//         vm.startPrank(crowdSalesOwner);
//         crowdSaleWithFees.updateCrowdSaleFees(20);
//         vm.stopPrank();

//         assertEq(crowdSaleWithFees.getCrowdSaleFees(saleId), 10);
//         assertEq(crowdSaleWithFees.getFees(), 20);
//     }

//     function testClaim() public {
//         vm.startPrank(emitter);
//         Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, auctionToken, biddingToken);
//         assertEq(_sale.beneficiary, emitter);
//         auctionToken.approve(address(crowdSaleWithFees), 400_000 ether);
//         uint256 saleId = crowdSaleWithFees.startSale(_sale);
//         vm.stopPrank();

//         vm.startPrank(bidder);
//         crowdSaleWithFees.placeBid(saleId, 200_000 ether, "");
//         vm.stopPrank();

//         vm.warp(block.timestamp + 2 hours + 1);

//         vm.startPrank(anyone);
//         crowdSaleWithFees.settle(saleId);
//         vm.stopPrank();

//         assertEq(biddingToken.balanceOf(emitter), 0);
//         vm.startPrank(anyone);
//         crowdSaleWithFees.claimResults(saleId);
//         vm.stopPrank();

//         assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal - _sale.fundingGoal * crowdSaleWithFees.getCrowdSaleFees(saleId) / 1000);
//         assertEq(biddingToken.balanceOf(crowdSalesOwner), _sale.fundingGoal * crowdSaleWithFees.getCrowdSaleFees(saleId) / 1000);
//     }
// }
