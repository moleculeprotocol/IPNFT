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
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 0);
        token.safeMint(bob);

        assertEq(token.validTokensAmount(bob), 1);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.isValid(0), true);

        string memory tokenUri_ = token.tokenURI(0);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMCIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiVE9ETzogRW50ZXIgSVAtTkZULVVJIFVSTCIsICJpbWFnZSI6ICJUT0RPOiBFbnRlciBJUEZTIFVSTCIsICJ2YWxpZCI6ICJWYWxpZCJ9"
        );

        vm.stopPrank();
    }


    function testSafeMintFromNotOwner() public {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.safeMint(alice);

        assertEq(token.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testTransfer() public {
        vm.startPrank(bob);
        vm.expectRevert("This a Soulbound token. It can only be burned.");
        token.transferFrom(bob, alice, 0);

        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testBurnFromOwner() public {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit TokenBurned(bob, bob, 0);
        token.burn(0);

        assertEq(token.validTokensAmount(bob), 0);
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromIpnftContract() public {
        vm.startPrank(ipnftContract);
        assertEq(token.ownerOf(0), bob);

        vm.expectEmit(true, true, true, true);
        emit TokenBurned(ipnftContract, bob, 0);
        token.burn(0);

        assertEq(token.validTokensAmount(bob), 0);
        assertEq(token.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromRandomUser() public {
        vm.startPrank(alice);
        vm.expectRevert("Not authorized to burn this token");
        token.burn(0);

        assertEq(token.validTokensAmount(bob), 1);
        assertEq(token.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testRevokeToken() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit Revoked(bob, 0);
        token.revoke(0);

        assertEq(token.isValid(0), false);
        assertEq(token.validTokensAmount(bob), 0);

        string memory tokenUri_ = token.tokenURI(0);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMCIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiVE9ETzogRW50ZXIgSVAtTkZULVVJIFVSTCIsICJpbWFnZSI6ICJUT0RPOiBFbnRlciBJUEZTIFVSTCIsICJ2YWxpZCI6ICJSZXZva2VkIn0="
        );
        vm.stopPrank();
    }

    function testRevokeFromRandomUser() public {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.revoke(0);

        assertEq(token.isValid(0), true);
        assertEq(token.validTokensAmount(bob), 1);
        vm.stopPrank();
    }
}
