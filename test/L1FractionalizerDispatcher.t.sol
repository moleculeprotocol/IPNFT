// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { console } from "forge-std/console.sol";
import { MockStandardBridge } from "./helpers/MockStandardBridge.sol";
import { MockCrossDomainMessenger } from "./helpers/MockCrossDomainMessenger.sol";
import { AuthorizeAll } from "./helpers/AuthorizeAll.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { ContractRegistry } from "../src/ContractRegistry.sol";
import { FractionalizerL2Dispatcher } from "../src/FractionalizerL2Dispatcher.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract L1FractionalizerDispatcher is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

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

        ContractRegistry registry = new ContractRegistry();
        registry.register("CrossdomainMessenger", address(new MockCrossDomainMessenger()));
        registry.register("StandardBridge", address(new MockStandardBridge()));
        registry.register("FractionalizerL2", makeAddr("fractionalizerAddrL2"));
        registry.register(address(myToken), makeAddr("myTokenOnL2"));

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

        vm.startPrank(originalOwner);
        uint256 reservationId = _ipnft.reserve();
        _ipnft.mintReservation(originalOwner, reservationId, 1, ipfsUri);
        vm.stopPrank();
    }

    function testInitiatingFractions() public {
        vm.startPrank(originalOwner);
        fractionalizer.initializeFractionalization(ipnft, 1, agreementHash, 100_000);
        vm.stopPrank();
    }

    function helpCreateListing(uint256 price) public returns (uint256 listingId) {
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.listFor(ipnft, 1, erc20, price, address(fractionalizer));

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        return listingId;
    }

    function testCreateListingAndSell() public {
        vm.startPrank(originalOwner);
        fractionalizer.initializeFractionalization(ipnft, 1, agreementHash, 100_000);
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
        uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, agreementHash, 100_000);
        uint256 listingId = helpCreateListing(1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        // this is wanted: *anyone* (!) can call this. This is an oracle call.
        vm.startPrank(charlie);
        fractionalizer.afterSale(fractionId, listingId);
        vm.stopPrank();
    }
    //todo test claim shares can be transferred to others and are still redeemable

    function testCollectionBalanceMustBeOne() public {
        //cant fractionalize 1155 tokens with a supply > 1
    }
}
