// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";

contract IPNFTTest is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string name, uint256 indexed reservationId);

    event IPNFTMinted(address indexed minter, uint256 indexed tokenId, uint256 indexed slotId);

    UUPSProxy proxy;
    IPNFT internal ipnft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string testURI = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string testURI2 = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setMintpassContract(address(mintpass));
        vm.stopPrank();
    }

    function testInitialDeploymentState() public {
        assertEq(ipnft.paused(), false);
        assertEq(ipnft.uri(0), "");
        assertEq(ipnft.totalSupply(0), 0);
    }

    function testTokenReservation() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit Reserved(bob, 1);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, testURI);

        (address reserver, string memory tokenURI) = ipnft.reservations(0);
        assertEq(reserver, bob);
        assertEq(tokenURI, testURI);
    }

    // function testTokenReservationCounter() public {
    //     vm.startPrank(bob);
    //     vm.expectEmit(true, true, true, true);
    //     // We emit the event we expect to see.
    //     emit Reserved(bob, 0);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);

    //     (address reserver, string memory tokenURI) = ipnft.reservations(0);
    //     assertEq(reserver, bob);
    //     assertEq(tokenURI, testURI);

    //     ipnft.reserve();
    //     (address reserver_2,) = ipnft.reservations(1);
    //     assertEq(reserver_2, bob);
    // }

    // function testMintFromReservation() public {
    //     vm.startPrank(bob);

    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     vm.expectEmit(true, false, false, true);
    //     emit PermanentURI(testURI, 0);

    //     vm.expectEmit(true, true, false, true);
    //     emit TokenMinted(testURI, bob, 0, 1);

    //     ipnft.mintReservation(bob, 0);
    //     assertEq(ipnft.balanceOf(bob, 0), 1);
    //     assertEq(ipnft.uri(0), testURI);

    //     (address reserver,) = ipnft.reservations(0);
    //     assertEq(reserver, address(0));

    //     vm.stopPrank();
    // }

    // function testTokenURIUpdate() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);

    //     assertEq(ipnft.uri(0), testURI);
    // }

    // function testBurn() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);
    //     assertEq(ipnft.balanceOf(bob, 0), 1);
    //     ipnft.burn(bob, 0, 1);

    //     assertEq(ipnft.balanceOf(bob, 0), 0);
    // }

    // function testUpdatedPrice() public {
    //     vm.startPrank(deployer);
    //     ipnft.updateMintPrice(1 ether);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     vm.expectRevert(bytes("Ether amount sent is too small"));
    //     ipnft.mintReservation(bob, 0);
    // }

    // function testChargeableMint() public {
    //     vm.startPrank(deployer);
    //     ipnft.updateMintPrice(tokenPrice);
    //     vm.stopPrank();

    //     vm.deal(bob, tokenPrice);
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation{value: tokenPrice}(bob, 0);

    //     assertEq(address(bob).balance, 0);
    //     assertEq(address(token).balance, tokenPrice);
    //     assertEq(ipnft.balanceOf(bob, 0), 1);
    // }

    // function testCantUpdateTokenURIOnMintedTokens() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);

    //     vm.expectRevert("IP-NFT: Reservation not valid or not owned by you");
    //     ipnft.updateReservationURI(0, testURI2);

    //     assertEq(ipnft.uri(0), testURI);
    // }

    // function testOnlyReservationOwnerCanMintFromReservation() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     vm.expectRevert("IP-NFT: caller is not reserver");
    //     ipnft.mintReservation(address(0xDEADCAFE), 0);
    //     vm.stopPrank();
    // }

    // function testOwnerWithdrawAll() public {
    //     vm.deal(address(token), 10 ether);
    //     assertEq(address(token).balance, 10 ether);

    //     vm.startPrank(deployer);
    //     ipnft.withdrawAll();
    //     vm.stopPrank();

    //     assertEq(address(token).balance, 0);
    //     assertEq(address(deployer).balance, 10 ether);
    // }

    // function testNonOwnerCannotWithdrawAll() public {
    //     vm.deal(address(token), 10 ether);
    //     assertEq(address(token).balance, 10 ether);

    //     vm.startPrank(bob);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     ipnft.withdrawAll();
    //     vm.stopPrank();

    //     assertEq(address(token).balance, 10 ether);
    //     assertEq(address(bob).balance, 0);
    // }

    // function testOwnerIncreaseShares() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);

    //     assertEq(ipnft.balanceOf(bob, 0), 1);

    //     ipnft.increaseShares(0, 9, bob);

    //     assertEq(ipnft.balanceOf(bob, 0), 10);
    //     assertEq(ipnft.totalSupply(0), 10);
    // }

    // function testNonOwnerCannotIncreaseShares() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);
    //     vm.stopPrank();

    //     assertEq(ipnft.balanceOf(bob, 0), 1);

    //     vm.startPrank(alice);
    //     vm.expectRevert("IP-NFT: not owner");
    //     ipnft.increaseShares(0, 9, bob);

    //     assertEq(ipnft.balanceOf(bob, 0), 1);
    //     assertEq(ipnft.totalSupply(0), 1);
    // }

    // function testCannotIncreaseSharesIfAlreadyMinted() public {
    //     vm.startPrank(bob);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.updateReservationURI(reservationId, testURI);
    //     ipnft.mintReservation(bob, 0);
    //     ipnft.increaseShares(0, 9, bob);

    //     assertEq(ipnft.balanceOf(bob, 0), 10);

    //     vm.expectRevert("IP-NFT: shares already minted");
    //     ipnft.increaseShares(0, 5, bob);

    //     assertEq(ipnft.balanceOf(bob, 0), 10);
    //     assertEq(ipnft.totalSupply(0), 10);
    // }
}
