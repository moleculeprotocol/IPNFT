// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";

import { Mintpass } from "../src/Mintpass.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { UUPSProxy } from "../src/UUPSProxy.sol";
import { console } from "forge-std/console.sol";

contract TestToken is ERC20("USD Coin", "USDC", 18) {
    function mintTo(address recipient, uint256 amount) public payable {
        _mint(recipient, amount);
    }
}

contract SchmackoSwapTest is Test {
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    Mintpass mintpass;
    IPNFT internal ipnft;
    IERC1155Supply internal erc1155Supply;

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
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        erc1155Supply = IERC1155Supply(address(ipnft));

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(seller, 1);

        TestToken _testToken = new TestToken();
        _testToken.mintTo(buyer, 1 ether);
        testToken = IERC20(address(_testToken));

        schmackoSwap = new SchmackoSwap();
        vm.stopPrank();

        vm.startPrank(seller);
        // Ensure marketplace can access sellers's tokens
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        ipnft.reserve();
        ipnft.mintReservation(seller, 1, 1, arUri);
        vm.stopPrank();
    }

    function testGeneralBalancesAndSupplies() public {
        assertEq(ipnft.balanceOf(seller, 1), 1);
        assertEq(ipnft.balanceOf(buyer, 1), 0);
        assertEq(ipnft.totalSupply(1), 1);
        assertEq(testToken.balanceOf(buyer), 1 ether);
        assertEq(testToken.balanceOf(seller), 0);
        assertEq(testToken.balanceOf(address(schmackoSwap)), 0);
    }

    function testCanCreateSale() public {
        uint256 listingId = uint256(
            keccak256(
                abi.encode(
                    SchmackoSwap.Listing({
                        tokenContract: erc1155Supply,
                        tokenId: 1,
                        paymentToken: testToken,
                        tokenAmount: erc1155Supply.totalSupply(1),
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
                tokenContract: erc1155Supply,
                tokenId: 1,
                paymentToken: testToken,
                tokenAmount: erc1155Supply.totalSupply(1),
                askPrice: 1 ether,
                creator: address(seller),
                beneficiary: address(seller),
                listingState: ListingState.LISTED
            })
            );

        schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        vm.stopPrank();

        //assertEq(ipnft.balanceOf(address(schmackoSwap), 1), 1);

        (
            IERC1155Supply tokenContract,
            uint256 tokenId,
            address creator,
            uint256 tokenAmount,
            IERC20 paymentToken,
            uint256 askPrice,
            address beneficiary,
            ListingState listingState
        ) = schmackoSwap.listings(listingId);

        assertEq(address(tokenContract), address(ipnft));
        assertEq(tokenId, 1);
        assertEq(tokenAmount, 1);
        assertEq(creator, address(seller));
        assertEq(beneficiary, address(seller));
        assertEq(askPrice, 1 ether);
        assertEq(address(paymentToken), address(testToken));
        assertEq(uint256(listingState), 0);
        assertEq(ipnft.balanceOf(address(seller), 1), 1);
    }

    function testNonOwnerCannotCreateSale() public {
        vm.prank(otherUser);
        vm.expectRevert(SchmackoSwap.InsufficientAllowance.selector);
        schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);

        assertEq(ipnft.balanceOf(seller, 1), 1);
    }

    function testCannotListWhenTokenIsNotApproved() public {
        vm.startPrank(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), false);

        vm.expectRevert(SchmackoSwap.InsufficientAllowance.selector);
        schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);

        assertEq(ipnft.balanceOf(seller, 1), 1);
    }

    function testCanCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);

        //todo test this emission
        vm.expectEmit(true, false, false, true);
        emit Unlisted(
            listingId,
            SchmackoSwap.Listing({
                tokenContract: erc1155Supply,
                tokenId: 1,
                tokenAmount: 1,
                paymentToken: testToken,
                askPrice: 1 ether,
                creator: address(seller),
                beneficiary: address(seller),
                listingState: ListingState.CANCELLED
            })
            );

        schmackoSwap.cancel(listingId);

        assertEq(ipnft.balanceOf(address(seller), 1), 1);
        (,, address newCreator,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), 1);
        assertEq(newCreator, seller);
    }

    function testNonOwnerCannotCancelSale() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        vm.stopPrank();

        vm.prank(otherUser);
        vm.expectRevert(SchmackoSwap.Unauthorized.selector);
        schmackoSwap.cancel(listingId);

        assertEq(ipnft.balanceOf(address(seller), 1), 1);

        (,, address creator,,,,,) = schmackoSwap.listings(listingId);
        assertEq(creator, address(seller));
    }

    function testSellerCanManageAllowlist() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
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
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert(SchmackoSwap.InsufficientAllowance.selector);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(address(seller), 1), 1);

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);
        testToken.transfer(address(0), 1 ether);
        vm.expectRevert(SchmackoSwap.InsufficientBalance.selector);
        schmackoSwap.fulfill(listingId);

        assertEq(ipnft.balanceOf(address(seller), 1), 1);
        vm.stopPrank();
    }

    function testCanBuyListing() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);

        vm.expectEmit(true, false, false, true);
        emit Purchased(
            listingId,
            address(buyer),
            SchmackoSwap.Listing({
                tokenContract: erc1155Supply,
                tokenId: 1,
                creator: address(seller),
                tokenAmount: 1,
                paymentToken: testToken,
                askPrice: 1 ether,
                beneficiary: address(seller),
                listingState: ListingState.FULFILLED
            })
            );

        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(address(buyer), 1), 1);
        assertEq(testToken.balanceOf(buyer), 0);
        assertEq(testToken.balanceOf(seller), 1 ether);

        // listing has been removed during sale
        (,, address creator,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), 2);
        assertEq(creator, seller);
    }

    function testCannotFulfillWhenSellerHasMovedTheNft() public {
        vm.startPrank(seller);
        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        ipnft.safeTransferFrom(seller, otherUser, 1, 1, "");
        assertEq(ipnft.balanceOf(otherUser, 1), 1);
        vm.stopPrank();

        vm.startPrank(buyer);
        testToken.approve(address(schmackoSwap), 1 ether);
        vm.expectRevert("ERC1155: insufficient balance for transfer");
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

        uint256 listingId = schmackoSwap.list(erc1155Supply, 1, testToken, 1 ether);
        vm.expectRevert("Can't add ZERO address to allowlist");
        schmackoSwap.changeBuyerAllowance(listingId, address(0), true);

        assertEq(schmackoSwap.isAllowed(listingId, address(0)), false);
    }

    function testCannotSendNftsToSchmackoswap() public {
        vm.startPrank(seller);
        vm.expectRevert(bytes("ERC1155: transfer to non-ERC1155Receiver implementer"));
        ipnft.safeTransferFrom(seller, address(schmackoSwap), 1, 1, "");
        vm.stopPrank();
    }
}
