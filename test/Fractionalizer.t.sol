// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    IERC1155Supply internal ipnft;
    Fractionalizer internal fractionalizer;
    SchmackoSwap internal schmackoSwap;

    IERC20 internal erc20;

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT _ipnft = IPNFT(address(proxy));
        _ipnft.initialize();
        ipnft = IERC1155Supply(address(_ipnft));

        schmackoSwap = new SchmackoSwap();
        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        Mintpass mintpass = new Mintpass(address(_ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        _ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(originalOwner, 1);

        fractionalizer = new Fractionalizer();
        fractionalizer.initialize();
        fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();

        vm.startPrank(originalOwner);
        uint256 reservationId = _ipnft.reserve();
        _ipnft.mintReservation(originalOwner, reservationId, 1, ipfsUri);
        vm.stopPrank();
    }

    function testIssueFractions() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeUniqueERC1155(ipnft, 1, agreementHash, 100_000);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 100_000);
        //the original nft *stays* at the owner
        assertEq(ipnft.balanceOf(originalOwner, 1), 1);

        (,, uint256 totalIssued,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 100_000);

        vm.startPrank(originalOwner);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 10_000, "");
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 10_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 90_000);
        assertEq(fractionalizer.totalSupply(fractionId), 100_000);
    }

    function testIncreaseFractions() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeUniqueERC1155(ipnft, 1, agreementHash, 100_000);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
        fractionalizer.safeTransferFrom(originalOwner, bob, fractionId, 25_000, "");

        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(bob, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 150_000);
        assertEq(fractionalizer.totalSupply(fractionId), 200_000);

        (,, uint256 totalIssued,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 200_000);
    }

    function helpCreateListing() public returns (uint256 fractionId, uint256 listingId) {
        vm.startPrank(originalOwner);
        fractionId = fractionalizer.fractionalizeUniqueERC1155(ipnft, 1, agreementHash, 100_000);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.listFor(ipnft, 1, erc20, 1_000_000 ether, address(fractionalizer));

        fractionalizer.listings(fractionId);
        assertFalse(listingId == 0);

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        vm.stopPrank();
    }

    function testCreateListingAndSell() public {
        (, uint256 listingId) = helpCreateListing();
        (,,,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), uint256(ListingState.LISTED));

        //todo: prove we cannot start withdrawals at this point ;)
        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(ipnftBuyer, 1), 1);
        assertEq(ipnft.balanceOf(originalOwner, 1), 0);
        assertEq(erc20.balanceOf(originalOwner), 0);
        assertEq(erc20.balanceOf(address(fractionalizer)), 1_000_000 ether);

        (,,,,,,, ListingState listingState2) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState2), uint256(ListingState.FULFILLED));
    }

    function testClaimBuyoutShares() public {
        (uint256 fractionId, uint256 listingId) = helpCreateListing();
        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        vm.startPrank(charlie); // *anyone* (!) can start this. This is an oracle call.
        fractionalizer.startWithdrawalsOrCancel(schmackoSwap, fractionId);
        vm.stopPrank();
    }

    function testCollectionBalanceMustBeOne() public {
        //cant fractionalize 1155 tokens with a supply > 1
    }
}
