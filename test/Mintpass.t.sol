// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Mintpass } from "../src/Mintpass.sol";

contract MintpassTest is Test {
    Mintpass public token;
    address deployer = address(0x1);
    address ipnftContract = address(0x2);
    address bob = address(0x3);
    address alice = address(0x4);

    event Revoked(address indexed owner, uint256 indexed tokenId);
    event TokenMinted(address indexed owner, uint256 indexed tokenId);
    event TokenBurned(address indexed from, address indexed owner, uint256 indexed tokenId);

    function setUp() public {
        vm.startPrank(deployer);
        token = new Mintpass(ipnftContract);
        vm.stopPrank();
    }

    function testSafeMintFromOwner() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);

        assertEq(token.balanceOf(bob), 1);
        assertEq(token.numberOfValidTokens(bob), 1);
        assertEq(token.isValid(0), true);

        string memory tokenUri_ = token.tokenURI(0);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIk1pbnRwYXNzIHRvIGNyZWF0ZSBhbiBJUC1ORlQiLCAiZGVzY3JpcHRpb24iOiAiVGhpcyBNaW50cGFzcyBjYW4gYmUgdXNlZCB0byBtaW50IGFuIElQLU5GVC4gVGhlIE1pbnRwYXNzIHdpbGwgZ2V0IGJ1cm5lZCBkdXJpbmcgdGhlIHByb2Nlc3MiLCAiZXh0ZXJuYWxfdXJsIjogIlRPRE86IEVudGVyIElQLU5GVC1VSSBVUkwiLCAiaW1hZ2UiOiJUT0RPOiBFbnRlciBJUEZTIFVSTCIsICJ0b2tlbklkIjoifQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIn0="
        );
        vm.stopPrank();
    }

    function testSafeMintFromNotOwner() public {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testTransfer() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("This a Soulbound token. It can only be burned.");
        token.transferFrom(bob, alice, 0);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testBurnFromOwner() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit TokenBurned(bob, bob, 0);
        vm.startPrank(bob);
        token.burn(0);
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromIpnftContract() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();

        vm.startPrank(ipnftContract);
        vm.expectEmit(true, true, true, true);
        emit TokenBurned(ipnftContract, bob, 0);
        assertEq(token.ownerOf(0), bob);
        token.burn(0);
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromRandomUser() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("Only the owner or ipnft contract can burn this token.");
        token.burn(0);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testRevokeToken() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.isValid(0), true);

        vm.expectEmit(true, true, true, true);
        emit Revoked(bob, 0);
        token.revoke(0);
        // bool isValid = token.isValid(0);
        assertEq(token.isValid(0), false);
        vm.stopPrank();
    }

    function testRevokeFromRandomUser() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.revoke(0);
        bool isValid = token.isValid(0);
        assertEq(isValid, true);
        vm.stopPrank();
    }
}
