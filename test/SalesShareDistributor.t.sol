// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";
import { IPermissioner, TermsAcceptedPermissioner, BlindPermissioner, InvalidSignature } from "../src/Permissioner.sol";

import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { Synthesizer } from "../src/Synthesizer.sol";

import {
    SalesShareDistributor,
    ListingNotFulfilled,
    ListingMismatch,
    NotClaimingYet,
    UncappedToken,
    OnlyIssuer,
    InsufficientBalance
} from "../src/SalesShareDistributor.sol";

import { Molecules, OnlyIssuerOrOwner } from "../src/Molecules.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";

contract SalesShareDistributorTest is Test {
    using SafeERC20Upgradeable for Molecules;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob  are molecules holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    uint256 bobPk;
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Synthesizer internal synthesizer;
    SalesShareDistributor internal distributor;
    SchmackoSwap internal schmackoSwap;

    FakeERC20 internal erc20;
    IPermissioner internal blindPermissioner;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        vm.startPrank(deployer);
        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        schmackoSwap = new SchmackoSwap();
        erc20 = new FakeERC20("Fake ERC20", "FERC");
        erc20.mint(ipnftBuyer, 1_000_000 ether);

        blindPermissioner = new BlindPermissioner();

        synthesizer = Synthesizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Synthesizer()
                    ),
                    ""
                )
            )
        );
        synthesizer.initialize(ipnft, blindPermissioner);

        distributor = SalesShareDistributor(
            address(
                new ERC1967Proxy(
                    address(
                        new SalesShareDistributor()
                    ),
                    ""
                )
            )
        );
        distributor.initialize(schmackoSwap);
        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
        vm.stopPrank();
    }

    function helpCreateListing(uint256 price, address beneficiary) public returns (uint256 listingId) {
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.list(IERC721(address(ipnft)), 1, erc20, price, beneficiary);

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        return listingId;
    }

    function testCreateListingAndSell() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(synthesizer), true);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        uint256 listingId = helpCreateListing(1_000_000 ether, address(tokenContract));
        vm.stopPrank();

        (,,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), uint256(ListingState.LISTED));

        //todo: prove we cannot start withdrawals at this point ;)
        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), ipnftBuyer);
        assertEq(ipnft.balanceOf(originalOwner), 0);
        assertEq(erc20.balanceOf(originalOwner), 0);
        assertEq(erc20.balanceOf(address(tokenContract)), 1_000_000 ether);

        (,,,,,, ListingState listingState2) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState2), uint256(ListingState.FULFILLED));
    }

    function testStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        // ipnft.setApprovalForAll(address(synthesizer), true);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");

        uint256 listingId = helpCreateListing(1_000_000 ether, address(distributor));
        vm.stopPrank();

        assertEq(tokenContract.issuer(), originalOwner);
        vm.startPrank(originalOwner);
        vm.expectRevert(ListingNotFulfilled.selector);
        distributor.afterSale(tokenContract, listingId, blindPermissioner);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(distributor)), 1_000_000 ether);

        vm.startPrank(originalOwner);
        vm.expectRevert(UncappedToken.selector);
        distributor.afterSale(tokenContract, listingId, blindPermissioner);

        tokenContract.cap();
        distributor.afterSale(tokenContract, listingId, blindPermissioner);
        vm.stopPrank();

        (uint256 fulfilledListingId,,,) = distributor.sales(address(tokenContract));
        assertEq(listingId, fulfilledListingId);
    }

    function testManuallyStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1);
        assertEq(tokenContract.issuer(), originalOwner);
        tokenContract.cap();
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(originalOwner, 1_000_000 ether);
        vm.stopPrank();

        // only the owner can manually start the claiming phase.
        vm.startPrank(bob);
        vm.expectRevert(OnlyIssuer.selector);
        distributor.afterSale(tokenContract, erc20, 1_000_000 ether, blindPermissioner);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.expectRevert(); // not approved
        distributor.afterSale(tokenContract, erc20, 1_000_000 ether, blindPermissioner);

        erc20.approve(address(distributor), 1_000_000 ether);
        distributor.afterSale(tokenContract, erc20, 1_000_000 ether, blindPermissioner);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(originalOwner)), 0);
        (uint256 fulfilledListingId,,,) = distributor.sales(address(tokenContract));
        assertTrue(fulfilledListingId != 0);
    }

    function testClaimBuyoutShares() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        tokenContract.cap();

        TermsAcceptedPermissioner permissioner = new TermsAcceptedPermissioner();

        tokenContract.safeTransfer(alice, 25_000);
        tokenContract.safeTransfer(bob, 25_000);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(originalOwner, 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1);
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(permissioner.specificTermsV1(tokenContract))));

        vm.startPrank(alice);
        //someone must start the claiming phase first
        vm.expectRevert(NotClaimingYet.selector);
        distributor.claim(tokenContract, abi.encodePacked(r, s, v));
        vm.stopPrank();

        vm.startPrank(originalOwner);
        erc20.approve(address(distributor), 1_000_000 ether);
        distributor.afterSale(tokenContract, erc20, 1_000_000 ether, permissioner);
        vm.stopPrank();

        vm.startPrank(alice);
        (, uint256 amount) = distributor.claimableTokens(tokenContract, alice);
        assertEq(amount, 250_000 ether);
        tokenContract.approve(address(distributor), 25_000 ether);
        distributor.claim(tokenContract, abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 250_000 ether);
        assertEq(erc20.balanceOf(address(distributor)), 750_000 ether);
        assertEq(tokenContract.totalSupply(), 75_000);

        assertEq(tokenContract.balanceOf(alice), 0);
        (, uint256 remainingAmount) = distributor.claimableTokens(tokenContract, alice);
        assertEq(remainingAmount, 0);

        //claims can be transferred to others and are redeemable by them
        (address charlie, uint256 charliePk) = makeAddrAndKey("charlie");

        vm.startPrank(bob);
        tokenContract.safeTransfer(charlie, 20_000);
        vm.stopPrank();

        (, uint256 claimableByCharlie) = distributor.claimableTokens(tokenContract, charlie);
        assertEq(claimableByCharlie, 200_000 ether);

        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(permissioner.specificTermsV1(tokenContract))));

        vm.startPrank(charlie);
        tokenContract.approve(address(distributor), 20_000 ether);
        distributor.claim(tokenContract, abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(charlie), 200_000 ether);
        assertEq(erc20.balanceOf(address(distributor)), 550_000 ether);
    }

    function testClaimBuyoutSharesAfterSwap() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        tokenContract.cap();

        uint256 listingId = helpCreateListing(1_000_000 ether, address(distributor));
        tokenContract.safeTransfer(alice, 25_000);

        TermsAcceptedPermissioner permissioner = new TermsAcceptedPermissioner();

        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        distributor.afterSale(tokenContract, listingId, permissioner);
        vm.stopPrank();

        vm.startPrank(alice);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(permissioner.specificTermsV1(tokenContract))));

        (IERC20 paymentToken, uint256 remainingAmount) = distributor.claimableTokens(tokenContract, alice);
        assertEq(address(paymentToken), address(erc20));
        assertEq(remainingAmount, 250_000 ether);
        tokenContract.approve(address(distributor), 25_000 ether);

        distributor.claim(tokenContract, abi.encodePacked(r, s, v));
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 250_000 ether);
        assertEq(erc20.balanceOf(address(distributor)), 750_000 ether);
        assertEq(tokenContract.totalSupply(), 75_000);

        assertEq(tokenContract.balanceOf(alice), 0);
        (, remainingAmount) = distributor.claimableTokens(tokenContract, alice);
        assertEq(remainingAmount, 0);
    }

    function testFuzzSynthesize(uint256 moleculesAmount, uint256 salesPrice) public {
        vm.assume(moleculesAmount <= 2 ** 200);
        vm.assume(salesPrice <= 100_000_000_000 ether);

        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, moleculesAmount, "MOLE", agreementCid, "");
        tokenContract.cap();

        assertEq(tokenContract.balanceOf(originalOwner), moleculesAmount);
        tokenContract.safeTransfer(alice, moleculesAmount);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.mint(ipnftBuyer, salesPrice);
        erc20.transfer(originalOwner, salesPrice);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        erc20.approve(address(distributor), salesPrice);
        distributor.afterSale(tokenContract, erc20, salesPrice, blindPermissioner);
        vm.stopPrank();
    }

    function testClaimingFraud() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract1 = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        tokenContract1.cap();
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId1 = schmackoSwap.list(IERC721(address(ipnft)), 1, erc20, 1000 ether, address(distributor));
        schmackoSwap.changeBuyerAllowance(listingId1, ipnftBuyer, true);

        vm.stopPrank();

        vm.deal(bob, MINTING_FEE);
        vm.startPrank(deployer);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(bob, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        Molecules tokenContract2 = synthesizer.synthesizeIpnft(2, 70_000, "MOLE", agreementCid, "");
        tokenContract2.cap();
        uint256 listingId2 = schmackoSwap.list(IERC721(address(ipnft)), 2, erc20, 700 ether, address(originalOwner));
        schmackoSwap.changeBuyerAllowance(listingId2, ipnftBuyer, true);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId1);
        schmackoSwap.fulfill(listingId2);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(InsufficientBalance.selector);
        distributor.afterSale(tokenContract2, listingId2, blindPermissioner);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.expectRevert(ListingMismatch.selector);
        distributor.afterSale(tokenContract1, listingId2, blindPermissioner);

        vm.expectRevert(OnlyIssuer.selector);
        distributor.afterSale(tokenContract2, listingId2, blindPermissioner);

        distributor.afterSale(tokenContract1, listingId1, blindPermissioner);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(InsufficientBalance.selector);
        distributor.claim(tokenContract1, bytes(""));
        vm.stopPrank();
    }
}
