// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";
import { SignedMintAuthorizer, SignedMintAuthorization } from "../src/SignedMintAuthorizer.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";

contract Kamikaze {
    receive() external payable { }

    function bazingaa(address payable heir) public {
        selfdestruct(heir);
    }
}

contract IPNFTTest is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event IPNFTMinted(address indexed owner, uint256 indexed tokenId, string tokenURI, string symbol);
    event SymbolUpdated(uint256 indexed tokenId, string symbol);
    event ReadAccessGranted(uint256 indexed tokenId, address indexed reader, uint256 until);
    event MetadataUpdate(uint256 tokenId);

    IPNFT internal ipnft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    uint256 alicePk;
    uint256 deployerPk;

    function setUp() public {
        (, alicePk) = makeAddrAndKey("alice");
        (, deployerPk) = makeAddrAndKey("chucknorris");

        vm.startPrank(deployer);
        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        vm.deal(alice, 0.05 ether);

        vm.stopPrank();
    }

    function testInitialDeploymentState() public {
        assertEq(ipnft.paused(), false);
    }

    function testTokenReservation() public {
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Reserved(alice, 1);
        ipnft.reserve();

        assertEq(ipnft.reservations(1), alice);
    }

    function testTokenReservationCounter() public {
        vm.startPrank(alice);
        ipnft.reserve();
        vm.stopPrank();

        vm.startPrank(bob);
        ipnft.reserve();

        assertEq(ipnft.reservations(2), bob);
    }

    function testVerifyPoi() public {
        uint256 tokenId = uint256(0x073cb54264ef688e56531a2d09ab47b14086b5c7813e3a23a2bd7b1bb6458a52);
        bool isPoi = verifyPoi(tokenId);
        assertEq(isPoi, true);
    }

    function testMintWithPoi() public {
        bytes32 poiHash = 0x073cb54264ef688e56531a2d09ab47b14086b5c7813e3a23a2bd7b1bb6458a52;
        uint256 tokenId = uint256(poiHash);
        bytes32 authMessageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(alice, alice, tokenId, ipfsUri)));

        vm.startPrank(deployer);
        ipnft.setAuthorizer(new SignedMintAuthorizer(deployer));
        vm.stopPrank();

        vm.startPrank(alice);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPk, authMessageHash);
        bytes memory authorization = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(alice, tokenId, ipfsUri, DEFAULT_SYMBOL);
        ipnft.mintReservation{ value: MINTING_FEE }(alice, tokenId, ipfsUri, DEFAULT_SYMBOL, authorization);
        assertEq(ipnft.ownerOf(tokenId), alice);
        assertEq(ipnft.tokenURI(tokenId), ipfsUri);
        assertEq(ipnft.symbol(tokenId), DEFAULT_SYMBOL);

        vm.stopPrank();
    }

    function testMintFromReservation() public {
        vm.startPrank(deployer);
        ipnft.setAuthorizer(new SignedMintAuthorizer(deployer));
        vm.stopPrank();

        bytes32 authMessageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(alice, alice, uint256(1), ipfsUri)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, authMessageHash); //alice is not an authorized signer!
        bytes memory authorization = abi.encodePacked(r, s, v);

        vm.startPrank(alice);
        uint256 reservationId = ipnft.reserve();

        vm.expectRevert(IPNFT.MintingFeeTooLow.selector);
        ipnft.mintReservation(alice, reservationId, ipfsUri, DEFAULT_SYMBOL, authorization);

        vm.expectRevert(IPNFT.Unauthorized.selector);
        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId, ipfsUri, DEFAULT_SYMBOL, authorization);

        (v, r, s) = vm.sign(deployerPk, authMessageHash);
        authorization = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(alice, 1, ipfsUri, DEFAULT_SYMBOL);
        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId, ipfsUri, DEFAULT_SYMBOL, authorization);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.tokenURI(1), ipfsUri);
        assertEq(ipnft.symbol(reservationId), DEFAULT_SYMBOL);

        vm.stopPrank();
    }

    function testBurn() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        vm.startPrank(alice);

        ipnft.burn(tokenId);

        assertEq(ipnft.balanceOf(alice), 0);
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        reserveAToken(ipnft, alice);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPNFT.NotOwningReservation.selector, 1));
        ipnft.mintReservation(bob, 1, arUri, DEFAULT_SYMBOL, "");
        vm.stopPrank();
    }

    /**
     * default payments are rejected by EIP1967...
     */
    function testCannotSendPlainEtherToIPNFT() public {
        vm.deal(address(bob), 10 ether);

        vm.startPrank(bob);
        (bool transferWorked,) = address(ipnft).call{ value: 10 ether }("");
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
        vm.startPrank(bob);
        Kamikaze kamikaze = new Kamikaze();
        (bool transferWorked,) = address(kamikaze).call{ value: 10 ether }("");
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
        vm.expectRevert(IPNFT.BadDuration.selector);
        ipnft.grantReadAccess(bob, tokenId, block.timestamp);

        vm.expectEmit(true, true, false, true);
        emit ReadAccessGranted(tokenId, bob, block.timestamp + 60);
        ipnft.grantReadAccess(bob, tokenId, block.timestamp + 60);
        assertTrue(ipnft.canRead(bob, tokenId));
        vm.warp(block.timestamp + 55);
        assertTrue(ipnft.canRead(bob, tokenId));

        vm.warp(block.timestamp + 60);
        assertFalse(ipnft.canRead(bob, tokenId));
    }

    function testOwnerCanAmendMetadataAfterSignoff() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        ipnft.setAuthorizer(new SignedMintAuthorizer(deployer));
        vm.stopPrank();

        bytes32 authMessageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(alice, alice, uint256(1), "ipfs://QmNewUri")));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPk, authMessageHash);
        bytes memory authorization = abi.encodePacked(r, s, v);

        //the signoff only allows alice to call this
        vm.startPrank(charlie);
        vm.expectRevert(IPNFT.Unauthorized.selector);
        ipnft.amendMetadata(1, "ipfs://QmNewUri", authorization);

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, false);
        emit MetadataUpdate(1);
        ipnft.amendMetadata(1, "ipfs://QmNewUri", authorization);
        assertEq(ipnft.tokenURI(1), "ipfs://QmNewUri");
        vm.stopPrank();
    }
}
