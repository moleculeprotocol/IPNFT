// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

//import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";

import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import {
    Fractionalizer,
    Fractionalized,
    ToZeroAddress,
    AlreadyClaiming,
    MustOwnIpnft,
    ListingNotFulfilled,
    ListingMismatch,
    InsufficientBalance,
    NotClaimingYet
} from "../src/Fractionalizer.sol";
import { FractionalizedToken } from "../src/FractionalizedToken.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract FractionalizerSalesTest is Test {
    using SafeERC20Upgradeable for FractionalizedToken;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob  are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Fractionalizer internal fractionalizer;
    SchmackoSwap internal schmackoSwap;
    MyToken internal myToken;
    Mintpass internal mintpass;
    IERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(originalOwner, 1);

        fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Fractionalizer()
                    ), 
                    ""
                )
            )
        );
        fractionalizer.initialize(ipnft, schmackoSwap);
        fractionalizer.setFeeReceiver(protocolOwner);
        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, 1, ipfsUri, DEFAULT_SYMBOL);
        vm.stopPrank();
    }

    function helpCreateListing(uint256 price, address beneficiary) public returns (uint256 listingId) {
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.list(IERC1155Supply(address(ipnft)), 1, erc20, price, beneficiary);

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        return listingId;
    }

    function testCreateListingAndSell() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(fractionalizer), true);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);
        uint256 listingId = helpCreateListing(1_000_000 ether, address(tokenContract));
        vm.stopPrank();

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
        assertEq(erc20.balanceOf(address(tokenContract)), 1_000_000 ether);

        (,,,,,,, ListingState listingState2) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState2), uint256(ListingState.FULFILLED));
    }

    function testStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        // ipnft.setApprovalForAll(address(fractionalizer), true);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);

        uint256 listingId = helpCreateListing(1_000_000 ether, address(tokenContract));
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(ListingNotFulfilled.selector);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(tokenContract)), 1_000_000 ether);

        // this is wanted: *anyone* (!) can call this. This is an oracle call.
        vm.startPrank(bob);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(tokenContract)), 1_000_000 ether);
        (,,,,, uint256 fulfilledListingId,,) = fractionalizer.fractionalized(fractionId);
        assertEq(listingId, fulfilledListingId);

        vm.startPrank(bob);
        vm.expectRevert(AlreadyClaiming.selector);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.expectRevert(AlreadyClaiming.selector);
        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();
    }

    function testManuallyStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        erc20.approve(address(fractionalizer), 1_000_000 ether);
        ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1, 1, "");
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(originalOwner, 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(MustOwnIpnft.selector);
        fractionalizer.afterSale(fractionId, erc20, 1_000_000 ether);
        vm.stopPrank();
        vm.startPrank(originalOwner);
        // only the owner can manually start the claiming phase.
        fractionalizer.afterSale(fractionId, erc20, 1_000_000 ether);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(originalOwner)), 0);
        (,,,,, uint256 fulfilledListingId,,) = fractionalizer.fractionalized(fractionId);

        assertFalse(fulfilledListingId == 0);
    }

    function testClaimBuyoutShares() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);

        tokenContract.safeTransfer(alice, 25_000);
        tokenContract.safeTransfer(bob, 25_000);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(originalOwner, 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1, 1, "");
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(alice);
        //someone must start the claiming phase first
        vm.expectRevert(NotClaimingYet.selector);
        tokenContract.burn(abi.encodePacked(r, s, v));
        vm.stopPrank();

        vm.startPrank(originalOwner);
        erc20.approve(address(fractionalizer), 1_000_000 ether);
        fractionalizer.afterSale(fractionId, erc20, 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        (, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(amount, 250_000 ether);
        tokenContract.burn(abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 250_000 ether);
        assertEq(erc20.balanceOf(address(tokenContract)), 750_000 ether);
        assertEq(fractionalizer.totalSupply(fractionId), 75_000);

        assertEq(fractionalizer.balanceOf(alice, fractionId), 0);
        (, uint256 remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(remainingAmount, 0);

        //claims can be transferred to others and are redeemable by them
        (address charlie, uint256 charliePk) = makeAddrAndKey("charlie");

        vm.startPrank(bob);
        tokenContract.safeTransfer(charlie, 20_000);
        vm.stopPrank();

        (, uint256 claimableByCharlie) = fractionalizer.claimableTokens(fractionId, charlie);
        assertEq(claimableByCharlie, 200_000 ether);

        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(charlie);
        tokenContract.burn(abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(charlie), 200_000 ether);
        assertEq(erc20.balanceOf(address(tokenContract)), 550_000 ether);
    }

    function testClaimBuyoutSharesAfterSwap() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);
        uint256 listingId = helpCreateListing(1_000_000 ether, address(tokenContract));
        tokenContract.safeTransfer(alice, 25_000);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        // this is wanted: *anyone* (!) can call this. This is an oracle call.
        vm.startPrank(bob);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();

        vm.startPrank(alice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

        (IERC20 paymentToken, uint256 remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(address(paymentToken), address(erc20));
        assertEq(remainingAmount, 250_000 ether);
        tokenContract.burn(abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 250_000 ether);
        assertEq(erc20.balanceOf(address(tokenContract)), 750_000 ether);
        assertEq(fractionalizer.totalSupply(fractionId), 75_000);

        assertEq(fractionalizer.balanceOf(alice, fractionId), 0);
        (, remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(remainingAmount, 0);
    }

    function testFuzzFractionalize(uint256 fractionAmount, uint256 salesPrice) public {
        vm.assume(fractionAmount <= 2 ** 200);
        vm.assume(salesPrice <= 100_000_000_000 ether);

        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, fractionAmount, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), fractionAmount);
        tokenContract.safeTransfer(alice, fractionAmount);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        myToken.mint(ipnftBuyer, salesPrice);
        erc20.transfer(originalOwner, salesPrice);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        erc20.approve(address(fractionalizer), salesPrice);
        fractionalizer.afterSale(fractionId, erc20, salesPrice);
        vm.stopPrank();
    }

    function testClaimingFraud() public {
        vm.startPrank(originalOwner);
        uint256 fractionId1 = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId1);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId1 = schmackoSwap.list(IERC1155Supply(address(ipnft)), 1, erc20, 1000 ether, address(tokenContract));
        schmackoSwap.changeBuyerAllowance(listingId1, ipnftBuyer, true);
        vm.stopPrank();

        vm.deal(bob, MINTING_FEE);
        vm.startPrank(deployer);
        mintpass.batchMint(bob, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(bob, reservationId, 2, ipfsUri, DEFAULT_SYMBOL);
        uint256 fractionId2 = fractionalizer.fractionalizeIpnft(2, 70_000, agreementCid);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId2 = schmackoSwap.list(IERC1155Supply(address(ipnft)), 2, erc20, 700 ether, address(originalOwner));
        schmackoSwap.changeBuyerAllowance(listingId2, ipnftBuyer, true);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId1);
        schmackoSwap.fulfill(listingId2);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(ListingMismatch.selector);
        fractionalizer.afterSale(fractionId1, listingId2);

        vm.expectRevert(InsufficientBalance.selector);
        fractionalizer.afterSale(fractionId2, listingId2);

        fractionalizer.afterSale(fractionId1, listingId1);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId1))));

        vm.expectRevert(InsufficientBalance.selector);
        tokenContract.burn(abi.encodePacked(r, s, v));
        vm.stopPrank();
    }
}
