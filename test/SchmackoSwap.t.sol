// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { ERC1155Supply } from
    "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { console } from "forge-std/console.sol";

contract TestToken is ERC20("USD Coin", "USDC", 18) {
    function mintTo(address recipient, uint256 amount) public payable {
        _mint(recipient, amount);
    }
}

contract SchmackoSwapTest is Test {
    uint256 nftId;

    IPNFT internal nft;
    IPNFT implementationV2;
    UUPSProxy proxy;
    TestToken internal testToken;
    SchmackoSwap internal schmackoSwap;
    address seller = address(0x1);
    address buyer = address(0x2);
    address otherUser = address(0x3);
    address deployer = address(0x4);

    event Listed(uint256 listingId, SchmackoSwap.Listing listing);
    event Unlisted(uint256 listingId, SchmackoSwap.Listing listing);
    event Purchased(
        uint256 listingId, address indexed buyer, SchmackoSwap.Listing listing
    );
    event AllowlistUpdated(
        uint256 listingId, address indexed buyer, bool _isAllowed
    );

    function setUp() public {
        vm.startPrank(deployer);
        implementationV2 = new IPNFT();
        proxy = new UUPSProxy(address(implementationV2), "");
        nft = IPNFT(address(proxy));
        nft.initialize();
        vm.stopPrank();

        testToken = new TestToken();
        schmackoSwap = new SchmackoSwap();

        // Ensure marketplace can access tokens
        nft.setApprovalForAll(address(schmackoSwap), true);

        // Ensure marketplace can access sellers's tokens
        vm.startPrank(seller);
        nft.setApprovalForAll(address(schmackoSwap), true);
        nftId = nft.reserve();
        nft.mintReservation(seller, nftId);
        vm.stopPrank();

        testToken.mintTo(buyer, 1 ether);
    }

    function testSellerHasNFTBalance() public {
        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);
        assertEq(nft.balanceOf(buyer, nftId), 0);
        assertEq(nft.totalSupply(nftId), numTokensMinted);
    }

    function testCanCreateSale() public {
        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);

        // Calculate the id before hand since we don't have the listing created yet
        bytes32 _listingId = keccak256(
            abi.encode(
                SchmackoSwap.Listing({
                    tokenContract: nft,
                    tokenId: nftId,
                    tokenAmount: numTokensMinted,
                    paymentToken: testToken,
                    askPrice: 1 ether,
                    creator: address(seller)
                })
            )
        );
        uint256 listingId = uint256(_listingId);

        vm.startPrank(seller);
        vm.expectEmit(true, true, false, true);
        emit Listed(
            listingId,
            SchmackoSwap.Listing({
                tokenContract: nft,
                tokenId: nftId,
                tokenAmount: numTokensMinted,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller)
            })
            );

        schmackoSwap.list(nft, nftId, testToken, 1 ether);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        (
            ERC1155Supply tokenContract,
            uint256 tokenId,
            uint256 tokenAmount,
            address creator,
            ERC20 paymentToken,
            uint256 askPrice
        ) = schmackoSwap.listings(listingId);

        assertEq(address(tokenContract), address(nft));
        assertEq(tokenId, nftId);
        assertEq(tokenAmount, numTokensMinted);
        assertEq(creator, address(seller));
        assertEq(askPrice, 1 ether);
        assertEq(address(paymentToken), address(testToken));

        assertEq(nft.balanceOf(address(seller), nftId), 0);
    }

    function testNonOwnerCannotCreateSale() public {
        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);

        vm.prank(address(otherUser));
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        schmackoSwap.list(nft, nftId, testToken, 1 ether);

        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);
    }

    function testCannotListWhenTokenIsNotApproved() public {
        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);

        vm.startPrank(seller);
        nft.setApprovalForAll(address(schmackoSwap), false);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        schmackoSwap.list(nft, nftId, testToken, 1 ether);

        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);
    }

    function testCanCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        (,,, address creator,,) = schmackoSwap.listings(listingId);
        assertEq(creator, address(seller));
        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        vm.expectEmit(true, false, false, true);
        emit Unlisted(
            listingId,
            SchmackoSwap.Listing({
                tokenContract: nft,
                tokenId: nftId,
                tokenAmount: numTokensMinted,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller)
            })
            );
        schmackoSwap.cancel(listingId);

        assertEq(nft.balanceOf(address(seller), nftId), numTokensMinted);

        (,,, address newCreator,,) = schmackoSwap.listings(listingId);
        assertEq(newCreator, address(0));
    }

    function testNonOwnerCannotCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        (,,, address creator,,) = schmackoSwap.listings(listingId);
        assertEq(creator, address(seller));
        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);
        vm.stopPrank();

        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        schmackoSwap.cancel(listingId);

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        (,,, address newCreator,,) = schmackoSwap.listings(listingId);
        assertEq(newCreator, address(seller));
    }

    function testCannotBuyNotExistingValue() public {
        vm.expectRevert(abi.encodeWithSignature("ListingNotFound()"));
        schmackoSwap.fulfill(1);
    }

    function testCannotBuyWithoutAllowance() public {
        vm.deal(buyer, 1 ether);

        assertEq(nft.balanceOf(seller, nftId), numTokensMinted);

        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);

        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);

        vm.expectEmit(true, true, false, false);
        emit AllowlistUpdated(listingId, address(buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance()"));
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);
    }

    function testCannotBuyWithInsufficientBalance() public {
        vm.deal(buyer, 1 ether);

        assertEq(nft.balanceOf(address(seller), nftId), numTokensMinted);

        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);

        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);

        vm.expectEmit(true, true, false, false);
        emit AllowlistUpdated(listingId, address(buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);
        testToken.transfer(address(0), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);
    }

    function testCanBuyListing() public {
        vm.deal(buyer, 1 ether);

        assertEq(nft.balanceOf(address(seller), nftId), numTokensMinted);

        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);

        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);

        vm.expectEmit(false, false, false, true);
        emit AllowlistUpdated(listingId, address(buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(schmackoSwap), nftId), numTokensMinted);

        vm.startPrank(buyer);
        vm.expectEmit(true, false, false, true);
        emit Purchased(
            listingId,
            address(buyer),
            SchmackoSwap.Listing({
                tokenContract: nft,
                tokenId: nftId,
                tokenAmount: numTokensMinted,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller)
            })
            );

        testToken.approve(address(schmackoSwap), 1 ether);

        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(nft.balanceOf(address(buyer), nftId), numTokensMinted);
        assertEq(testToken.balanceOf(buyer), 0);
        assertEq(testToken.balanceOf(seller), 1 ether);

        // Expect listing to be removed after buy
        (,,, address creator,,) = schmackoSwap.listings(listingId);
        assertEq(creator, address(0));
    }

    function testCannotAddToAllowListforNonexistingListing() public {
        vm.startPrank(seller);
        vm.expectRevert(abi.encodeWithSignature("ListingNotFound()"));
        schmackoSwap.changeBuyerAllowance(1, buyer, true);
    }

    function testCannotRemoveFromAllowListforNonexistingListing() public {
        vm.startPrank(seller);
        vm.expectRevert(abi.encodeWithSignature("ListingNotFound()"));
        schmackoSwap.changeBuyerAllowance(1, buyer, false);
    }

    function testCanAddToAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);

        vm.expectEmit(false, false, false, true);
        emit AllowlistUpdated(listingId, address(buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);

        assertEq(schmackoSwap.isAllowed(listingId, buyer), true);
    }

    function testCannotAddZeroAddressToAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        vm.expectRevert("Can't add ZERO address to allowlist");
        schmackoSwap.changeBuyerAllowance(listingId, address(0), true);

        assertEq(schmackoSwap.isAllowed(listingId, address(0)), false);
    }

    function testonlySellerCanAddToAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);
        vm.stopPrank();

        vm.startPrank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);

        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);
    }

    function testCanRemoveFromAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);

        vm.expectEmit(false, false, false, true);
        emit AllowlistUpdated(listingId, address(buyer), true);
        emit AllowlistUpdated(listingId, address(buyer), false);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);

        assertEq(schmackoSwap.isAllowed(listingId, buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, false);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);
    }

    function testonlySellerCanRemoveFromAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(nft, nftId, testToken, 1 ether);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);

        vm.expectEmit(false, false, false, true);
        emit AllowlistUpdated(listingId, address(buyer), true);

        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        vm.startPrank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        schmackoSwap.changeBuyerAllowance(listingId, buyer, false);

        assertEq(schmackoSwap.isAllowed(listingId, buyer), true);
    }

    function testTokenBalances() public {
        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);
        assertEq(testToken.balanceOf(address(schmackoSwap)), 0);
    }
}
