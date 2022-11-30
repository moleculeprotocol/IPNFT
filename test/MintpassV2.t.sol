// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { MintpassV2 } from "../src/MintpassV2.sol";

contract MintpassTestV2 is Test {
    MintpassV2 public mintPass;
    address deployer = address(0x1);
    address ipnftContract = address(0x2);
    address bob = address(0x3);
    address alice = address(0x4);

    event Revoked(uint256 indexed tokenId);
    event TokenMinted(address indexed owner, uint256 indexed tokenId);
    event TokenBurned(address indexed from, uint256 indexed tokenId);

    function setUp() public {
        vm.startPrank(deployer);
        mintPass = new MintpassV2(ipnftContract);
        vm.stopPrank();
    }

    function testSingleMints() public {
        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(alice, 1);
        mintPass.batchMint(alice, 1);
        vm.stopPrank();

        assertEq(mintPass.balanceOf(alice), 1);
        assertEq(mintPass.ownerOf(1), alice);
        assertEq(mintPass.isRedeemable(1), true);

        string memory tokenUri_ = mintPass.tokenURI(1);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMSIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiVE9ETzogRW50ZXIgSVAtTkZULVVJIFVSTCIsICJpbWFnZSI6ICJUT0RPOiBpbWFnZVVSSSIsICJ2YWxpZCI6IHRydWUiLCAicmVkZWVtZWQiOiB0cnVlfQ=="
        );

        vm.startPrank(deployer);
        vm.expectEmit(true, true, true, true);
        emit TokenMinted(bob, 2);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        assertEq(mintPass.balanceOf(bob), 1);
        assertEq(mintPass.ownerOf(2), bob);

        assertEq(mintPass.totalSupply(), 2);
    }

    function testBatchMintTen() public {
        vm.startPrank(deployer);
        mintPass.batchMint(alice, 10);
        vm.stopPrank();

        assertEq(mintPass.balanceOf(alice), 10);
        assertEq(mintPass.ownerOf(1), alice);
        assertEq(mintPass.ownerOf(10), alice);
    }

    function testBatchMintFifty() public {
        vm.startPrank(deployer);
        mintPass.batchMint(alice, 50);
        vm.stopPrank();

        assertEq(mintPass.balanceOf(alice), 50);
        assertEq(mintPass.ownerOf(1), alice);
        assertEq(mintPass.ownerOf(50), alice);
    }

    function testSafeMintFromNotOwner() public {
        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        mintPass.batchMint(alice, 1);

        assertEq(mintPass.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testTransfer() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("This a Soulbound token. It can only be burned.");
        mintPass.transferFrom(bob, alice, 1);

        assertEq(mintPass.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testBurnFromOwner() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit TokenBurned(bob, 1);
        mintPass.burn(1);

        assertEq(mintPass.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromIpnftContract() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(ipnftContract);
        assertEq(mintPass.ownerOf(1), bob);

        vm.expectEmit(true, true, true, true);
        emit TokenBurned(ipnftContract, 1);
        mintPass.burn(1);

        assertEq(mintPass.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function testBurnFromRandomUser() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert();
        mintPass.burn(1);

        assertEq(mintPass.balanceOf(bob), 1);
        vm.stopPrank();
    }

    function testRevokeToken() public {
        vm.startPrank(deployer);
        mintPass.batchMint(alice, 1);
        vm.expectEmit(true, true, true, true);
        emit Revoked(1);
        mintPass.revoke(1);

        assertEq(mintPass.isRedeemable(1), false);

        string memory tokenUri_ = mintPass.tokenURI(1);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMSIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiVE9ETzogRW50ZXIgSVAtTkZULVVJIFVSTCIsICJpbWFnZSI6ICJUT0RPOiBpbWFnZVVSSSIsICJ2YWxpZCI6IGZhbHNlIiwgInJlZGVlbWVkIjogdHJ1ZX0="
        );
        vm.stopPrank();
    }

    function testRevokeFromRandomUser() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        mintPass.revoke(1);

        assertEq(mintPass.isRedeemable(1), true);
        vm.stopPrank();
    }

    function testFailTokenUri0() public view {
        mintPass.tokenURI(0);
    }
}
