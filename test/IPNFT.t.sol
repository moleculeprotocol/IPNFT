// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/IPNFT.sol";

contract IPNFTTest is Test {
    string tokenName = "Molecule IP-NFT";
    string tokenSymbol = "IPNFT";
    IPNFT public token;
    address bob = address(0x1);
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
        token.safeMint(address(0xBEEF), testURI);

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(0), address(0xBEEF));
    }

    // Mint a token as non-owner
    function testPublicMint() public {
        vm.startPrank(bob);
        token.safeMint(address(0xBEEF), testURI);
        vm.stopPrank();

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(0), address(0xBEEF));
    }

    function testTokenURI() public {
        token.safeMint(address(0xBEEF), testURI);
        assertEq(token.tokenURI(0), testURI);
    }

    function testBurn() public {
        token.safeMint(bob, testURI);
        vm.startPrank(bob);
        token.burn(0);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 0);

        vm.expectRevert("ERC721: invalid token ID");
        token.ownerOf(0);
    }

    function testOwnerTokenURIUpdate() public {
        token.safeMint(bob, testURI);
        assertEq(token.tokenURI(0), testURI);
        token.updateTokenURI(0, testURI2);
        assertEq(token.tokenURI(0), testURI2);
    }

     function testPublicTokenURIUpdate() public {
        token.safeMint(bob, testURI);

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        token.updateTokenURI(0, testURI2);
        vm.stopPrank();
    }

     function testUpdatedPrice() public {
        token.updatePrice(1 ether);
        vm.expectRevert("Ether amount sent is not correct");
        token.safeMint(bob, testURI);
    }

    function testChargeableMint() public {
        token.updatePrice(tokenPrice);

        vm.deal(bob, tokenPrice);
        vm.startPrank(bob);
        token.safeMint{value: tokenPrice}(bob, testURI);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 1);
        assertEq(token.ownerOf(0), bob);
    }
}
