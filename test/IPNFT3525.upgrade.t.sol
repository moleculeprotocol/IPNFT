// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IPNFT3525V2} from "../src/IPNFT3525V2.sol";
import {IPNFT3525V21} from "../src/IPNFT3525V21.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";
import {Mintpass} from "../src/Mintpass.sol";

contract UpgradeV2toV21Test is Test {
    IPNFT3525V2 implementationV2;

    UUPSProxy proxy;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    IPNFT3525V2 ipnftV2;
    IPNFT3525V21 ipnftV21;
    Mintpass mintpass;

    function dealMintpass(address to) internal {
        vm.startPrank(deployer);
        mintpass.safeMint(to);
        vm.stopPrank();
    }

    //we're always starting on a V2 contract.
    function setUp() public {
        vm.startPrank(deployer);
        implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnftV2 = IPNFT3525V2(address(proxy));
        ipnftV2.initialize();
        mintpass = new Mintpass(address(ipnftV2));
        ipnftV2.setMintpassContract(address(mintpass));
        vm.stopPrank();
    }

    function deployUpgrade() public {
        vm.startPrank(deployer);
        IPNFT3525V21 implementationV21 = new IPNFT3525V21();
        ipnftV2.upgradeTo(address(implementationV21));

        ipnftV21 = IPNFT3525V21(address(proxy));
        assertEq(ipnftV21.name(), "IP-NFT V2.1");
        vm.stopPrank();
    }

    function testNFTsSurviveTheUpgrade() public {
        dealMintpass(alice);

        vm.startPrank(alice);
        uint256 reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(reservationId, "IP Title", arUri);
        ipnftV2.mintReservation(alice, reservationId, 1);
        vm.stopPrank();

        assertEq(ipnftV2.totalSupply(), 1);
        assertEq(ipnftV2.balanceOf(alice), 1);
        assertEq(ipnftV2.slotOf(1), 1);

        deployUpgrade();

        assertEq(ipnftV21.totalSupply(), 1);
        assertEq(ipnftV21.balanceOf(alice), 1);
        assertEq(ipnftV21.slotOf(1), 1);

        //see DEFAULT_VALUE on V2
        assertEq(ipnftV21.balanceOf(1), 1_000_000);
    }

    function testMoveFractionsOnUpgradedNfts() public {
        dealMintpass(alice);

        vm.startPrank(alice);
        uint256 reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(reservationId, "IP Title", arUri);
        ipnftV2.mintReservation(alice, reservationId, 1);
        vm.stopPrank();

        //don't tell your parents that this is visible on V2:
        assertEq(ipnftV2.balanceOf(1), 1_000_000);
        vm.stopPrank();

        deployUpgrade();

        vm.startPrank(alice);
        uint256[] memory fractions = new uint256[](2);
        fractions[0] = 500_000;
        fractions[1] = 500_000;

        ipnftV21.split(1, fractions);
        vm.stopPrank();

        assertEq(ipnftV21.totalSupply(), 2);
        assertEq(ipnftV21.balanceOf(alice), 2);
        assertEq(ipnftV21.balanceOf(1), 500_000);
        assertEq(ipnftV21.balanceOf(2), 500_000);
        assertEq(ipnftV21.slotOf(2), 1);
    }

    function testFailCantTransferValueOnV2() public {
        vm.startPrank(alice);
        uint256 reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(reservationId, "IP Title", arUri);
        ipnftV2.mintReservation(alice, reservationId, 1);
        ipnftV2.transferFrom(1, bob, 5);
        vm.stopPrank();
    }

    function testValueTransfersWorkOnV21() public {
        dealMintpass(alice);
        dealMintpass(bob);

        vm.startPrank(alice);
        uint256 reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(reservationId, "Alices IP", arUri);
        ipnftV2.mintReservation(alice, reservationId, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(reservationId, "Bobs IP", ipfsUri);
        ipnftV2.mintReservation(bob, reservationId, 2);
        vm.stopPrank();

        deployUpgrade();

        assertEq(ipnftV21.slotOf(1), 1);
        assertEq(ipnftV21.tokenSupplyInSlot(1), 1);
        assertEq(ipnftV21.tokenSupplyInSlot(2), 1);

        vm.startPrank(alice);
        ipnftV21.transferFrom(1, charlie, 5);
        vm.stopPrank();

        assertEq(ipnftV21.balanceOf(charlie), 1);
        assertEq(ipnftV21.balanceOf(alice), 1);
        assertEq(ipnftV21.ownerOf(3), charlie);
        assertEq(ipnftV21.balanceOf(3), 5);
        assertEq(ipnftV21.balanceOf(1), 999_995);
        assertEq(ipnftV21.slotOf(1), 1);
        assertEq(ipnftV21.slotOf(2), 2);
        assertEq(ipnftV21.slotOf(3), 1);

        //todo this *must* be 2, no?
        //assertEq(ipnftV21.tokenSupplyInSlot(1), 1);

        vm.startPrank(alice);
        ipnftV21.transferFrom(1, charlie, 100);
        vm.stopPrank();

        assertEq(ipnftV21.balanceOf(1), 999_895);
        assertEq(ipnftV21.balanceOf(4), 100);
        assertEq(ipnftV21.ownerOf(4), charlie);

        vm.startPrank(charlie);
        uint256[] memory tokensToMerge = new uint256[](2);
        tokensToMerge[0] = 4;
        tokensToMerge[1] = 3;

        ipnftV21.merge(tokensToMerge);
        vm.stopPrank();

        assertEq(ipnftV21.balanceOf(3), 105);
        assertEq(ipnftV21.ownerOf(3), charlie);

        //and now, lets reserve sth on V2.1
        vm.startPrank(alice);
        reservationId = ipnftV21.reserve();
        ipnftV2.updateReservation(reservationId, "Alices 2nd IP", ipfsUri);
        uint256 newSlotOnV3 = ipnftV2.mintReservation(alice, reservationId, 1);
        vm.stopPrank();

        assertEq(newSlotOnV3, 3);
        assertEq(ipnftV21.ownerOf(5), alice);

        assertEq(ipnftV21.slotOf(5), 3);
    }
}
