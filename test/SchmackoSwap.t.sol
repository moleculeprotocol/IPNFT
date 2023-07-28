// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";

contract SchmackoSwapTest is Test {
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 constant MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "IPT-0001";

    IPNFT internal ipnft;
    IERC721 internal ierc721;

    IERC20 internal testToken;
    SchmackoSwap internal schmackoSwap;

    address deployer = makeAddr("chucknorris");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address otherUser = makeAddr("otherUser");

    event Listed(uint256 listingId, SchmackoSwap.Listing listing);
    event Unlisted(uint256 listingId, SchmackoSwap.Listing listing);
    event Purchased(uint256 listingId, address indexed buyer, SchmackoSwap.Listing listing);
    event AllowlistUpdated(uint256 listingId, address indexed buyer, bool _isAllowed);

    function setUp() public {
        vm.startPrank(deployer);
        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        ierc721 = IERC721(address(ipnft));

        FakeERC20 _testToken = new FakeERC20("Fakium", "FAKE20");
        _testToken.mint(buyer, 1 ether);
        testToken = IERC20(address(_testToken));

        schmackoSwap = new SchmackoSwap();
        vm.stopPrank();

        vm.deal(seller, 0.001 ether);
        vm.startPrank(seller);
        // Ensure marketplace can access sellers's tokens
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        ipnft.reserve();
        ipnft.mintReservation{ value: 0.001 ether }(seller, 1, arUri, DEFAULT_SYMBOL, "");
        vm.stopPrank();
    }

    function testGeneralBalancesAndSupplies() public {
        assertEq(ipnft.balanceOf(seller), 1);
        assertEq(ipnft.balanceOf(buyer), 0);
        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);
        assertEq(testToken.balanceOf(address(schmackoSwap)), 0);
    }

    function testCanCreateSale() public {
        uint256 listingId = uint256(
            keccak256(
                abi.encode(
                    SchmackoSwap.Listing({
                        tokenContract: ierc721,
                        tokenId: 1,
                        paymentToken: testToken,
                        askPrice: 1 ether,
                        creator: address(seller),
                        beneficiary: address(seller),
                        listingState: ListingState.LISTED
                    }),
                    block.number
                )
            )
        );

        vm.startPrank(seller);
        //todo test this emission test is ok
        vm.expectEmit(true, true, false, true);
        emit Listed(
            listingId,
            SchmackoSwap.Listing({
                tokenContract: ierc721,
                tokenId: 1,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller),
                beneficiary: address(seller),
                listingState: ListingState.LISTED
            })
        );

        schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        vm.stopPrank();

        //assertEq(ipnft.balanceOf(address(schmackoSwap), 1), 1);

        (
            IERC721 tokenContract,
            uint256 tokenId,
            address creator,
            IERC20 paymentToken,
            uint256 askPrice,
            address beneficiary,
            ListingState listingState
        ) = schmackoSwap.listings(listingId);

        assertEq(address(tokenContract), address(ipnft));
        assertEq(tokenId, 1);
        assertEq(creator, address(seller));
        assertEq(beneficiary, address(seller));
        assertEq(askPrice, 1 ether);
        assertEq(address(paymentToken), address(testToken));
        assertEq(uint256(listingState), 0);
        assertEq(ipnft.ownerOf(1), seller);
    }

    function testNonOwnerCannotCreateSale() public {
        vm.prank(otherUser);
        vm.expectRevert(SchmackoSwap.InsufficientAllowance.selector);
        schmackoSwap.list(ierc721, 1, testToken, 1 ether);

        assertEq(ipnft.ownerOf(1), seller);
    }

    function testCannotListWhenTokenIsNotApproved() public {
        vm.startPrank(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), false);

        vm.expectRevert(SchmackoSwap.InsufficientAllowance.selector);
        schmackoSwap.list(ierc721, 1, testToken, 1 ether);

        assertEq(ipnft.ownerOf(1), seller);
    }

    function testCanCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);

        //todo test this emission
        vm.expectEmit(true, false, false, true);
        emit Unlisted(
            listingId,
            SchmackoSwap.Listing({
                tokenContract: ierc721,
                tokenId: 1,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller),
                beneficiary: address(seller),
                listingState: ListingState.CANCELLED
            })
        );

        schmackoSwap.cancel(listingId);

        assertEq(ipnft.ownerOf(1), seller);
        (,, address newCreator,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), 1);
        assertEq(newCreator, seller);
    }

    function testNonOwnerCannotCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        vm.stopPrank();

        vm.prank(otherUser);
        vm.expectRevert(SchmackoSwap.Unauthorized.selector);
        schmackoSwap.cancel(listingId);

        assertEq(ipnft.ownerOf(1), seller);

        (,, address creator,,,,) = schmackoSwap.listings(listingId);
        assertEq(creator, address(seller));
    }

    function testSellerCanManageAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);
        vm.stopPrank();

        vm.startPrank(otherUser);
        vm.expectRevert(SchmackoSwap.Unauthorized.selector);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);

        vm.startPrank(seller);
        vm.expectEmit(false, false, false, true);
        emit AllowlistUpdated(listingId, address(buyer), true);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);

        assertEq(schmackoSwap.isAllowed(listingId, buyer), true);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, false);
        assertEq(schmackoSwap.isAllowed(listingId, buyer), false);
    }

    function testCanOnlyBuyWithSufficientBalance() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, otherUser, true);
        vm.stopPrank();

        vm.startPrank(otherUser);
        vm.expectRevert("ERC20: insufficient allowance");
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), seller);

        vm.startPrank(otherUser);
        testToken.approve(address(schmackoSwap), 1 ether);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        schmackoSwap.fulfill(listingId);

        assertEq(ipnft.ownerOf(1), seller);
        vm.stopPrank();
    }

    function testCanBuyListing() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit Purchased(
            listingId,
            address(buyer),
            SchmackoSwap.Listing({
                tokenContract: ierc721,
                tokenId: 1,
                creator: address(seller),
                paymentToken: testToken,
                askPrice: 1 ether,
                beneficiary: address(seller),
                listingState: ListingState.FULFILLED
            })
        );

        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), buyer);
        assertEq(testToken.balanceOf(buyer), 0);
        assertEq(testToken.balanceOf(seller), 1 ether);

        // listing has been removed during sale
        (,, address creator,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), 2);
        assertEq(creator, seller);
    }

    function testCannotFulfillWhenSellerHasMovedTheNft() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        ipnft.safeTransferFrom(seller, otherUser, 1);
        assertEq(ipnft.ownerOf(1), otherUser);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();
    }

    function testCannotBuyNotExistingValue() public {
        vm.expectRevert(SchmackoSwap.ListingNotFound.selector);
        schmackoSwap.fulfill(1);
    }

    function testCannotManageAllowListsForNonexistingListing() public {
        vm.startPrank(seller);
        vm.expectRevert(SchmackoSwap.ListingNotFound.selector);
        schmackoSwap.changeBuyerAllowance(1, buyer, true);

        vm.expectRevert(SchmackoSwap.ListingNotFound.selector);
        schmackoSwap.changeBuyerAllowance(1, buyer, false);

        uint256 listingId = schmackoSwap.list(ierc721, 1, testToken, 1 ether);
        vm.expectRevert("Can't add ZERO address to allowlist");
        schmackoSwap.changeBuyerAllowance(listingId, address(0), true);

        assertEq(schmackoSwap.isAllowed(listingId, address(0)), false);
    }

    function testCannotSendNftsToSchmackoswap() public {
        vm.startPrank(seller);
        vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver implementer"));
        ipnft.safeTransferFrom(seller, address(schmackoSwap), 1);
        vm.stopPrank();
    }
}
