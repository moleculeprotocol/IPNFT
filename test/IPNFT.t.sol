// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract Kamikaze {
    receive() external payable { }

    function bazingaa(address payable heir) public {
        selfdestruct(heir);
    }
}

contract IPNFTTest is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event IPNFTMinted(address indexed owner, uint256 indexed tokenId, string tokenURI);
    event SymbolUpdated(uint256 indexed tokenId, string symbol);

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
        ipnft.setAuthorizer(address(mintpass));

        vm.deal(alice, 0.05 ether);

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

        assertEq(ipnft.reservations(1), alice);
    }

    function testTokenReservationCounter() public {
        dealMintpass(alice);
        vm.startPrank(alice);
        ipnft.reserve();
        vm.stopPrank();

        dealMintpass(bob);
        vm.startPrank(bob);
        ipnft.reserve();

        assertEq(ipnft.reservations(2), bob);
    }

    function testMintFromReservation() public {
        dealMintpass(alice);

        vm.startPrank(alice);
        uint256 reservationId = ipnft.reserve();

        vm.expectRevert(IPNFT.MintingFeeTooLow.selector);
        ipnft.mintReservation(alice, reservationId, 1, ipfsUri);

        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(alice, 1, ipfsUri);
        vm.expectEmit(true, false, false, false);
        emit SymbolUpdated(reservationId, DEFAULT_SYMBOL);
        ipnft.mintReservation{value: MINTING_FEE}(alice, reservationId, reservationId, ipfsUri, DEFAULT_SYMBOL);

        assertEq(ipnft.balanceOf(alice, 1), 1);
        assertEq(ipnft.uri(1), ipfsUri);
        assertEq(ipnft.symbol(reservationId), DEFAULT_SYMBOL);

        assertEq(ipnft.reservations(1), address(0));

        vm.stopPrank();
    }

    function testBurn() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        vm.startPrank(alice);

        ipnft.burn(alice, tokenId, 1);

        assertEq(ipnft.balanceOf(alice, tokenId), 0);
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        reserveAToken(ipnft, alice);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPNFT.NotOwningReservation.selector, 1));
        ipnft.mintReservation(bob, 1, 1, arUri);
        vm.stopPrank();
    }

    /**
     * default payments are rejected by EIP1967...
     */
    function testCannotSendPlainEtherToIPNFT() public {
        vm.deal(address(bob), 10 ether);

        vm.prank(bob);
        (bool transferWorked,) = address(ipnft).call{value: 10 ether}("");
        assertFalse(transferWorked);
        assertEq(address(ipnft).balance, 0);

        vm.expectRevert(bytes(""));
        payable(address(ipnft)).transfer(10 ether);

        vm.stopPrank();
    }

    /**
     * ... but when set as heir of a self destruct operation the contract accepts the money.
     */

    function testOwnerCanWithdrawEthFunds() public {
        vm.deal(address(bob), 10 ether);
        vm.prank(bob);
        Kamikaze kamikaze = new Kamikaze();
        (bool transferWorked,) = address(kamikaze).call{value: 10 ether}("");
        assertTrue(transferWorked);
        assertEq(address(kamikaze).balance, 10 ether);

        kamikaze.bazingaa(payable(address(ipnft)));

        assertEq(address(ipnft).balance, 10 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert("Ownable: caller is not the owner");
        ipnft.withdrawAll();
        vm.stopPrank();

        assertEq(address(deployer).balance, 0);
        vm.startPrank(deployer);
        ipnft.withdrawAll();
        vm.stopPrank();

        assertEq(address(ipnft).balance, 0);
        assertEq(address(deployer).balance, 10 ether);
    }

    function testCanWithdrawMintingFees() public {
        mintAToken(ipnft, alice);

        assertEq(address(ipnft).balance, 0.001 ether);
        vm.startPrank(deployer);
        ipnft.withdrawAll();
        vm.stopPrank();
        assertEq(address(ipnft).balance, 0 ether);
        assertEq(deployer.balance, 0.001 ether);
    }

    function testCannotMintWhenPaused() public {
        vm.startPrank(deployer);
        ipnft.pause();
        vm.expectRevert(bytes("Pausable: paused"));
        ipnft.reserve();
        vm.stopPrank();
    }

    function testOwnerCanGrantReadAccess() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        //owners can always read
        assertTrue(ipnft.canRead(alice, tokenId));

        assertFalse(ipnft.canRead(bob, tokenId));

        vm.expectRevert(IPNFT.InsufficientBalance.selector);
        ipnft.grantReadAccess(bob, tokenId, block.timestamp + 60);

        vm.startPrank(alice);
        vm.expectRevert(bytes("until in the past"));
        ipnft.grantReadAccess(bob, tokenId, block.timestamp);

        ipnft.grantReadAccess(bob, tokenId, block.timestamp + 60);
        assertTrue(ipnft.canRead(bob, tokenId));
        vm.warp(block.timestamp + 55);
        assertTrue(ipnft.canRead(bob, tokenId));

        vm.warp(block.timestamp + 60);
        assertFalse(ipnft.canRead(bob, tokenId));
    }

    function testOwnerCanUpdateSymbol() public {
        uint256 tokenId = mintAToken(ipnft, alice);
        assertEq(ipnft.symbol(tokenId), DEFAULT_SYMBOL);

        vm.startPrank(alice);
        ipnft.updateSymbol(tokenId, "ALICE-123");
        vm.stopPrank();

        assertEq(ipnft.symbol(tokenId), "ALICE-123");
        vm.startPrank(bob);
        vm.expectRevert(IPNFT.InsufficientBalance.selector);
        ipnft.updateSymbol(tokenId, "BOB-314");
        vm.stopPrank();
    }
}
