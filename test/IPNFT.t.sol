// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IPNFT} from "../src/IPNFT.sol";

contract IPNFTTest is Test {
    event Reserved(address indexed reserver, uint256 indexed reservationId);

    event TokenMinted(
        string tokenURI,
        address indexed owner,
        uint256 indexed tokenId,
        uint256 sharesAmount
    );

    event PermanentURI(string _value, uint256 indexed _id);

    IPNFT public token;
    address bob = address(0x1);
    address alice = address(0x2);
    address deployer = address(0x3);
    string testURI = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string testURI2 = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        token = new IPNFT();
        vm.stopPrank();
    }

    function testInitialDeploymentState() public {
        assertEq(token.paused(), false);
        assertEq(token.uri(0), "");
        assertEq(token.totalSupply(0), 0);
        assertEq(token.mintPrice(), 0 ether);
    }

    function testTokenReservation() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        // We emit the event we expect to see.
        emit Reserved(bob, 0);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);

        (address reserver, string memory tokenURI) = token.reservations(0);
        assertEq(reserver, bob);
        assertEq(tokenURI, testURI);
    }

    function testTokenReservationCounter() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        // We emit the event we expect to see.
        emit Reserved(bob, 0);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);

        (address reserver, string memory tokenURI) = token.reservations(0);
        assertEq(reserver, bob);
        assertEq(tokenURI, testURI);

        token.reserve();
        (address reserver_2, ) = token.reservations(1);
        assertEq(reserver_2, bob);
    }

    function testMintFromReservation() public {
        vm.startPrank(bob);

        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        vm.expectEmit(true, false, false, true);
        emit PermanentURI(testURI, 0);

        vm.expectEmit(true, true, false, true);
        emit TokenMinted(testURI, bob, 0, 1);

        token.mintReservation(bob, 0);
        assertEq(token.balanceOf(bob, 0), 1);
        assertEq(token.uri(0), testURI);

        (address reserver, ) = token.reservations(0);
        assertEq(reserver, address(0));

        vm.stopPrank();
    }

    function testTokenURIUpdate() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);

        assertEq(token.uri(0), testURI);
    }

    function testBurn() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        assertEq(token.balanceOf(bob, 0), 1);
        token.burn(bob, 0, 1);

        assertEq(token.balanceOf(bob, 0), 0);
    }

    function testUpdatedPrice() public {
        vm.startPrank(deployer);
        token.updateMintPrice(1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        vm.expectRevert(bytes("Ether amount sent is too small"));
        token.mintReservation(bob, 0);
    }

    function testChargeableMint() public {
        vm.startPrank(deployer);
        token.updateMintPrice(tokenPrice);
        vm.stopPrank();

        vm.deal(bob, tokenPrice);
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation{value: tokenPrice}(bob, 0);

        assertEq(address(bob).balance, 0);
        assertEq(address(token).balance, tokenPrice);
        assertEq(token.balanceOf(bob, 0), 1);
    }

    function testCantUpdateTokenURIOnMintedTokens() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);

        vm.expectRevert("IP-NFT: Reservation not valid or not owned by you");
        token.updateReservationURI(0, testURI2);

        assertEq(token.uri(0), testURI);
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("IP-NFT: caller is not reserver");
        token.mintReservation(address(0xDEADCAFE), 0);
        vm.stopPrank();
    }

    function testOwnerWithdrawAll() public {
        vm.deal(address(token), 10 ether);
        assertEq(address(token).balance, 10 ether);

        vm.startPrank(deployer);
        token.withdrawAll();
        vm.stopPrank();

        assertEq(address(token).balance, 0);
        assertEq(address(deployer).balance, 10 ether);
    }

    function testNonOwnerCannotWithdrawAll() public {
        vm.deal(address(token), 10 ether);
        assertEq(address(token).balance, 10 ether);

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.withdrawAll();
        vm.stopPrank();

        assertEq(address(token).balance, 10 ether);
        assertEq(address(bob).balance, 0);
    }

    function testOwnerIncreaseShares() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);

        assertEq(token.balanceOf(bob, 0), 1);

        token.increaseShares(0, 9, bob);

        assertEq(token.balanceOf(bob, 0), 10);
        assertEq(token.totalSupply(0), 10);
    }

    function testNonOwnerCannotIncreaseShares() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        vm.stopPrank();

        assertEq(token.balanceOf(bob, 0), 1);

        vm.startPrank(alice);
        vm.expectRevert("IP-NFT: not owner");
        token.increaseShares(0, 9, bob);

        assertEq(token.balanceOf(bob, 0), 1);
        assertEq(token.totalSupply(0), 1);
    }

    function testCannotIncreaseSharesIfAlreadyMinted() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        token.increaseShares(0, 9, bob);

        assertEq(token.balanceOf(bob, 0), 10);

        vm.expectRevert("IP-NFT: shares already minted");
        token.increaseShares(0, 5, bob);

        assertEq(token.balanceOf(bob, 0), 10);
        assertEq(token.totalSupply(0), 10);
    }
}
