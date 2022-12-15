// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { Mintpass } from "../src/Mintpass.sol";

contract MintpassTest is Test {
    Mintpass public mintPass;
    address deployer = address(0x1);
    address ipnftContract = address(0x2);
    address bob = address(0x3);
    address alice = address(0x4);

    event Revoked(uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public {
        vm.startPrank(deployer);
        mintPass = new Mintpass(ipnftContract);
        mintPass.grantRole(mintPass.MODERATOR(), deployer);
        vm.stopPrank();
    }

    function testGrantingAndRevokingOfModeratorRole() public {
        vm.startPrank(deployer);
        mintPass.grantRole(mintPass.MODERATOR(), bob);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        assertEq(mintPass.ownerOf(1), bob);
        assertEq(mintPass.balanceOf(bob), 1);

        vm.startPrank(bob);
        mintPass.batchMint(alice, 1);
        vm.stopPrank();

        assertEq(mintPass.ownerOf(2), alice);
        assertEq(mintPass.balanceOf(alice), 1);

        vm.startPrank(deployer);
        mintPass.revokeRole(mintPass.MODERATOR(), bob);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert();
        mintPass.batchMint(alice, 1);
        vm.stopPrank();
    }

    function testSingleMints() public {
        vm.startPrank(deployer);
        mintPass.batchMint(alice, 1);
        vm.stopPrank();

        assertEq(mintPass.balanceOf(alice), 1);
        assertEq(mintPass.ownerOf(1), alice);
        assertEq(mintPass.isRedeemable(1), true);

        string memory tokenUri_ = mintPass.tokenURI(1);
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMSIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiaHR0cHM6Ly9tb2xlY3VsZS50byIsICJpbWFnZSI6ICJhcjovL0s4WnlVOWZXU01nRXgwYkRSbXdkMHNYR20xUEtiX0RyMkItMjd5TXF5M1kiLCAiYXR0cmlidXRlcyI6IFt7ICJ0cmFpdF90eXBlIjogIlN0YXR1cyIsICJ2YWx1ZSI6ICJyZWRlZW1hYmxlIn1d"
        );

        vm.startPrank(deployer);
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
        vm.expectRevert();
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
        emit Transfer(bob, address(0), 1);
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
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMSIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiaHR0cHM6Ly9tb2xlY3VsZS50byIsICJpbWFnZSI6ICJhcjovL2ctWkY5TmV3VWlvMkI3NENoQ1FOMHgwY2ozbGlaUHhqMEg3d0gtdjV5OTgiLCAiYXR0cmlidXRlcyI6IFt7ICJ0cmFpdF90eXBlIjogIlN0YXR1cyIsICJ2YWx1ZSI6ICJyZXZva2VkIn1d"
        );
        vm.stopPrank();
    }

    function testRevokeFromRandomUser() public {
        vm.startPrank(deployer);
        mintPass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert();
        mintPass.revoke(1);

        assertEq(mintPass.isRedeemable(1), true);
        vm.stopPrank();
    }

    function testFailTokenUri0() public view {
        mintPass.tokenURI(0);
    }
}
