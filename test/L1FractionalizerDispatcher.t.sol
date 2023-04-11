// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockStandardBridge } from "./helpers/MockStandardBridge.sol";
import { MockCrossDomainMessenger } from "./helpers/MockCrossDomainMessenger.sol";
import { AuthorizeAll } from "./helpers/AuthorizeAll.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { TestERC1155 } from "./helpers/TestERC1155.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { ContractRegistry } from "../src/ContractRegistry.sol";
import { FractionalizerL2Dispatcher } from "../src/FractionalizerL2Dispatcher.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract L1FractionalizerDispatcher is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");

    IERC1155Supply internal ipnft;
    FractionalizerL2Dispatcher internal fractionalizer;
    SchmackoSwap internal schmackoSwap;

    IERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");

        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV2), "");
        IPNFT _ipnft = IPNFT(address(proxy));
        _ipnft.initialize();
        ipnft = IERC1155Supply(address(_ipnft));

        schmackoSwap = new SchmackoSwap();
        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        _ipnft.setAuthorizer(address(new AuthorizeAll()));

        IL1ERC20Bridge bridge = new MockStandardBridge();
        ContractRegistry registry = new ContractRegistry();

        registry.register("CrossdomainMessenger", address(new MockCrossDomainMessenger()));
        registry.register("StandardBridge", address(bridge));
        registry.register("FractionalizerL2", makeAddr("fractionalizerAddrL2"));

        registry.register(bytes32(keccak256(abi.encodePacked("bridge.", address(erc20)))), address(bridge));
        registry.register(bytes32(keccak256(abi.encodePacked("l2.", address(erc20)))), makeAddr("myTokenOnL2"));

        fractionalizer = FractionalizerL2Dispatcher(
            address(
                new ERC1967Proxy(
                    address(
                        new FractionalizerL2Dispatcher()
                    ), ""
                )
            )
        );
        fractionalizer.initialize(schmackoSwap, registry);

        vm.stopPrank();

        vm.deal(originalOwner, 0.001 ether);
        vm.startPrank(originalOwner);
        uint256 reservationId = _ipnft.reserve();
        _ipnft.mintReservation{ value: 0.001 ether }(originalOwner, reservationId, 1, ipfsUri);
        vm.stopPrank();
    }

    function testInitiatingFractions() public {
        vm.startPrank(originalOwner);
        ipnft.setApprovalForAll(address(fractionalizer), true);
        fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
        vm.stopPrank();
    }

    function helpCreateListing(uint256 price) public returns (uint256 listingId) {
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.list(ipnft, 1, erc20, price, address(fractionalizer));

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        return listingId;
    }

    function testCreateListingAndSell() public {
        vm.startPrank(originalOwner);
        ipnft.setApprovalForAll(address(fractionalizer), true);
        fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
        uint256 listingId = helpCreateListing(1_000_000 ether);
        vm.stopPrank();

        (,,,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), uint256(ListingState.LISTED));

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

    function testStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        ipnft.setApprovalForAll(address(fractionalizer), true);
        uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
        uint256 listingId = helpCreateListing(1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();
        assertEq(erc20.balanceOf(address(fractionalizer)), 1_000_000 ether);

        // this is wanted: *anyone* (!) can call this. This is an oracle call.
        vm.startPrank(charlie);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(fractionalizer)), 0);
        (,,, uint256 fulfilledListingId) = fractionalizer.fractionalized(fractionId);
        assertEq(listingId, fulfilledListingId);
    }

    function testManuallyStartClaimingPhase() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
        erc20.approve(address(fractionalizer), 1_000_000 ether);
        ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1, 1, "");
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(originalOwner, 1_000_000 ether);
        vm.stopPrank();

        // this is wanted: *anyone* (!) can call this. This is an oracle call.
        vm.startPrank(originalOwner);
        fractionalizer.afterSale(fractionId, erc20, 1_000_000 ether);
        vm.stopPrank();

        assertEq(erc20.balanceOf(address(originalOwner)), 0);
        (,,, uint256 fulfilledListingId) = fractionalizer.fractionalized(fractionId);
        assertFalse(fulfilledListingId == 0);
    }

    function testCollectionBalanceMustBeOne() public {
        //cant fractionalize 1155 tokens with a supply > 1
        vm.startPrank(originalOwner);
        TestERC1155 erc1155 = new TestERC1155("");
        erc1155.mint(alice, 314, 10);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.expectRevert("can only fractionalize ERC1155 tokens with a supply of 1");
        fractionalizer.initializeFractionalization(IERC1155Supply(address(erc1155)), 1, alice, "", 100_000);
        vm.stopPrank();
    }
}
