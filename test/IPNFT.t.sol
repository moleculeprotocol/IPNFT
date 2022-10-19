// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/IPNFT.sol";

contract IPNFTTest is Test {
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

    // Mint a token as contract owner
    function testOwnerMint() public {
        token.safeMint(address(0xBEEF), testURI, true);

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(0), address(0xBEEF));
    }

    // Mint a token as non-owner
    function testPublicMint() public {
        vm.startPrank(bob);
        token.safeMint(address(0xBEEF), testURI, true);
        vm.stopPrank();

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(0), address(0xBEEF));
    }

    function testTokenURI() public {
        token.safeMint(address(0xBEEF), testURI, true);
        assertEq(token.tokenURI(0), testURI);
    }

    function testBurn() public {
        token.safeMint(bob, testURI, true);
        vm.startPrank(bob);
        token.burn(0);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 0);

        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(0);
    }

     function testUpdatedPrice() public {
        token.updatePrice(1 ether);
        vm.expectRevert("Ether amount sent is not correct");
        token.safeMint(bob, testURI, true);
    }

    function testChargeableMint() public {
        token.updatePrice(tokenPrice);

        vm.deal(bob, tokenPrice);
        vm.startPrank(bob);
        token.safeMint{value: tokenPrice}(bob, testURI, true);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 1);
        assertEq(token.ownerOf(0), bob);
    }

    function testTempMintAndFinalize() public {
        vm.startPrank(bob);
        token.safeMint(bob, testURI, false);
        token.finalizeMetadata(0, testURI2);
        vm.stopPrank();

        assertEq(token.tokenURI(0), testURI2);
    }

    function testAlreadyFinalized() public {
        vm.startPrank(bob);
        token.safeMint(bob, testURI, true);
        vm.expectRevert('Metadata was already finalized');
        token.finalizeMetadata(0, testURI2);
        vm.stopPrank();

        assertEq(token.tokenURI(0), testURI);
    }

     function testForeignFinalizeFail() public {
        vm.startPrank(bob);
        token.safeMint(bob, testURI, true);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert('ERC721: caller is not token owner or approved');
        token.finalizeMetadata(0, testURI2);
        vm.stopPrank();

        assertEq(token.tokenURI(0), testURI);
    }
}
