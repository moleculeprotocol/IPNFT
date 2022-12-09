// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract IPNFTTest is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string name, uint256 indexed reservationId);

    event IPNFTMinted(address indexed minter, uint256 indexed tokenId, string tokenURI);

    UUPSProxy proxy;
    IPNFT internal ipnft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

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
        assertEq(ipnft.uri(1), "");
        assertEq(ipnft.totalSupply(1), 0);
    }

    function testTokenReservation() public {
        vm.startPrank(alice);

        vm.expectRevert(IPNFT.NeedsMintpass.selector);
        uint256 reservationId = ipnft.reserve();
        vm.stopPrank();

        dealMintpass(alice);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Reserved(alice, 1);
        reservationId = ipnft.reserve();

        ipnft.updateReservation(reservationId, ipfsUri);

        (address reserver, string memory tokenURI) = ipnft.reservations(1);
        assertEq(reserver, alice);
        assertEq(tokenURI, ipfsUri);
    }

    function testTokenReservationCounter() public {
        dealMintpass(alice);
        vm.startPrank(alice);
        ipnft.reserve();
        vm.stopPrank();

        dealMintpass(bob);
        vm.startPrank(bob);
        ipnft.reserve();
        (address reserver,) = ipnft.reservations(2);
        assertEq(reserver, bob);
    }

    function testMintFromReservation() public {
        dealMintpass(alice);

        vm.startPrank(alice);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, ipfsUri);

        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(alice, 1, ipfsUri);

        ipnft.mintReservation(alice, 1, 1);

        assertEq(ipnft.balanceOf(alice, 1), 1);
        assertEq(ipnft.uri(1), ipfsUri);

        (address reserver,) = ipnft.reservations(1);
        assertEq(reserver, address(0));

        vm.stopPrank();
    }

    function testBurn() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        vm.startPrank(alice);

        ipnft.burn(alice, tokenId, 1);

        assertEq(ipnft.balanceOf(alice, tokenId), 0);
    }

    function testCantUpdateTokenURIOnMintedTokens() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IPNFT.NotOwningReservation.selector, tokenId));
        ipnft.updateReservation(tokenId, ipfsUri);
        vm.stopPrank();
        assertEq(ipnft.uri(tokenId), arUri);
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        reserveAToken(ipnft, alice, arUri);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPNFT.NotOwningReservation.selector, 1));
        ipnft.mintReservation(bob, 1, 1);
        vm.stopPrank();
    }

    function testOwnerCanWithdrawAllFunds() public {
        vm.deal(address(ipnft), 10 ether);
        assertEq(address(ipnft).balance, 10 ether);

        vm.startPrank(charlie);
        vm.expectRevert("Ownable: caller is not the owner");
        ipnft.withdrawAll();
        vm.stopPrank();

        vm.startPrank(deployer);
        ipnft.withdrawAll();
        vm.stopPrank();

        assertEq(address(ipnft).balance, 0);
        assertEq(address(deployer).balance, 10 ether);
    }

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
