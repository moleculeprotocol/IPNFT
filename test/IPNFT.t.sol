// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/IPNFT.sol";

contract IPNFTTest is Test {
    event Reserved(
        address indexed reserver,
        uint256 indexed reservationId
    );

    event TokenMinted(
        string tokenURI,
        address indexed owner,
        uint256 indexed tokenId
    );

    event PermanentURI(string _value, uint256 indexed _id);

    string tokenName = "Molecule IP-NFT";
    string tokenSymbol = "IPNFT";
    IPNFT public token;
    address bob = address(0x1);
    address alice = address(0x2);
    string testURI = "https://ipfs.io/ipfs/QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string testURI2 = "https://arweave.net/QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        token = new IPNFT(tokenName, tokenSymbol);
    }

    function testMetadata() public {
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), tokenSymbol);
    }

    // Reserve a token as contract owner
    function testOwnerReservation() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        // We emit the event we expect to see.
        emit Reserved(bob, 0);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);

        (address reserver, ) = token.reservations(0);
        assertEq(reserver, bob);
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        assertEq(token.ownerOf(0), address(0x0));

        //token.safeMint(address(0xBEEF), testURI, true);
        assertEq(token.balanceOf(bob), 0);
    }

    // Mint a token as non-owner
    function testMintFromReservation() public {
        vm.startPrank(bob);

        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        vm.expectEmit(true, false, false, true);
        emit PermanentURI(testURI, 0);

        vm.expectEmit(true, true, false, true);
        emit TokenMinted(testURI, address(0xDEADBEEF), 0);

        token.mintReservation(address(0xDEADBEEF), 0);
        assertEq(token.ownerOf(0), address(0xDEADBEEF));
        assertEq(token.balanceOf(address(0xDEADBEEF)), 1);

        (address reserver, ) = token.reservations(0);
        assertEq(reserver, address(0x0));

        vm.stopPrank();
    }

    function testTokenURI() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        assertEq(token.tokenURI(0), testURI);
    }

    function testBurn() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        token.burn(0);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 0);

        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(0);
    }

    function testUpdatedPrice() public {
        token.updatePrice(1 ether);

        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        vm.expectRevert(bytes("Ether amount sent is not correct"));
        token.mintReservation(bob, 0);
    }

    function testChargeableMint() public {
        token.updatePrice(tokenPrice);
        vm.deal(bob, tokenPrice);
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation{value: tokenPrice}(bob, 0);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 1);
        assertEq(token.ownerOf(0), bob);
    }

    function testCantUpdateTokenURIOnMintedTokens() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);

        vm.expectRevert("Reservation not valid or not owned by you");
        token.updateReservationURI(0, testURI2);
        vm.stopPrank();

        assertEq(token.tokenURI(0), testURI);
    }

    function testOnlyOwnerCanFreezeMetadata() public {
        vm.startPrank(bob);
        uint256 reservationId = token.reserve();
        token.updateReservationURI(reservationId, testURI);
        token.mintReservation(bob, 0);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("IP NFT: caller is not reserver");
        token.mintReservation(address(0xDEADCAFE), 0);
        vm.stopPrank();

        assertEq(token.tokenURI(0), testURI);
    }
}
