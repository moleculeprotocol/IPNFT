// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IPNFT3525V21 } from "../src/IPNFT3525V21.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract IPNFT3525V21Test is Test {
    IPNFT3525V21 implementationV21;
    UUPSProxy proxy;
    IPNFT3525V21 ipnft;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function reserveAToken(
        address to,
        string memory name,
        string memory tokenUri
    ) internal returns (uint256) {
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, name, tokenUri);
        //bytes memory ipnftArgs = abi.encode(title, tokenUri);
        return reservationId;
    }

    function mintAToken(address to, string memory name, string memory tokenUri)
        internal
        returns (uint256)
    {
        uint256 reservationId = reserveAToken(to, name, tokenUri);
        ipnft.mintReservation(to, reservationId, 1);
        return reservationId;
    }

    function setUp() public {
        vm.startPrank(deployer);
        implementationV21 = new IPNFT3525V21();
        proxy = new UUPSProxy(address(implementationV21), "");
        ipnft = IPNFT3525V21(address(proxy));
        ipnft.initialize();
        vm.stopPrank();
    }

    function testContractName() public {
        assertEq(ipnft.name(), "IP-NFT V2.1");
    }

    function testMinting() public {
        mintAToken(alice, "IP Title", arUri);

        assertEq(ipnft.totalSupply(), 1);
        string memory tokenUri_ = ipnft.tokenURI(1);

        //todo you obviously can't simply parse json in solidity. Add logic testing of this one to a hardhat test, maybe.
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJleHRlcm5hbF91cmwiOiJhcjovL3ROYmRIcWgzQVZESFZEMDZQME9QVVhTUHJvSTVrR2NaWnc4SXZMa2VrU1kifQ=="
        );

        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);
    }

    // todo: this is currently unsupported since I removed the initial fraction arg
    // function testCanMintWithMoreThanOneFraction() public {
    //     uint64[] memory fractions = new uint64[](2);
    //     fractions[0] = 50;
    //     fractions[1] = 50;

    //     bytes memory ipnftArgs = abi.encode("", "", "", fractions);

    //     ipnft.mint(alice, ipnftArgs);

    //     assertEq(ipnft.ownerOf(1), alice);
    //     assertEq(ipnft.ownerOf(2), alice);

    //     assertEq(ipnft.balanceOf(1), 50);
    //     assertEq(ipnft.balanceOf(2), 50);

    //     assertEq(ipnft.tokenSupplyInSlot(1), 2);
    // }

    function testSplitandMerge() public {
        mintAToken(alice, "IP Title", arUri);

        assertEq(ipnft.balanceOf(1), 1_000_000);
        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenSupplyInSlot(1), 1);

        vm.startPrank(alice);
        uint256[] memory fractions = new uint256[](2);
        fractions[0] = 500_000;
        fractions[1] = 500_000;

        //this creates another NFT on the same slot:
        ipnft.split(1, fractions);
        assertEq(ipnft.balanceOf(1), 500_000);
        assertEq(ipnft.balanceOf(2), 500_000);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), alice);

        assertEq(ipnft.slotOf(1), 1);
        assertEq(ipnft.slotOf(2), 1);

        //note that this is 2 now!
        assertEq(ipnft.tokenSupplyInSlot(1), 2);
        assertEq(ipnft.balanceOf(alice), 2);

        //note the merge order matters: we're merging towards the last token id in the list.
        uint256[] memory tokenIdsToMerge = new uint256[](2);
        tokenIdsToMerge[0] = 2;
        tokenIdsToMerge[1] = 1;

        ipnft.merge(tokenIdsToMerge);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.balanceOf(1), 1_000_000);

        //note that this is 1 again!
        assertEq(ipnft.tokenSupplyInSlot(1), 1);
        vm.stopPrank();
    }

    function testTransferValueToANewUser() public {
        vm.startPrank(alice);
        mintAToken(alice, "IP Title", arUri);
        ipnft.transferFrom(1, bob, 500_000);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), bob);
        assertEq(ipnft.balanceOf(1), 500_000);
        assertEq(ipnft.balanceOf(2), 500_000);

        //that's because both tokens yield the slot's metadata:
        assertEq(ipnft.tokenURI(1), ipnft.tokenURI(2));

        //todo this fails because tokenSupplyInSlot isn't increased during transfers.
        //https://github.com/Network-Goods/hypercerts-protocol/issues/54
        //assertEq(ipnft.tokenSupplyInSlot(1), 2);
    }

    //todo: this is disabled since I removed the initial fraction arg.
    // function testSplittingValuelessTokens() public {
    //     uint64[] memory fractions = new uint64[](1);
    //     fractions[0] = 0;

    //     vm.startPrank(alice);
    //     ipnft.mint(alice, abi.encode("", "", "", fractions));
    //     assertEq(ipnft.balanceOf(alice), 1);
    //     assertEq(ipnft.balanceOf(1), 0);

    //     ipnft.transferFrom(1, bob, 0);
    //     assertEq(ipnft.ownerOf(2), bob);
    //     assertEq(ipnft.totalSupply(), 2);

    //     vm.stopPrank();
    //     vm.startPrank(bob);
    //     ipnft.safeTransferFrom(bob, alice, 2);
    //     vm.stopPrank();
    //     vm.startPrank(alice);
    //     uint256[] memory tokenIdsToMerge = new uint256[](2);
    //     tokenIdsToMerge[0] = 2;
    //     tokenIdsToMerge[1] = 1;
    //     ipnft.merge(tokenIdsToMerge);
    //     //todo total supply is still 2!
    //     assertEq(ipnft.totalSupply(), 1);

    //     assertEq(ipnft.balanceOf(alice), 1);
    //     assertEq(ipnft.balanceOf(1), 0);

    //     ipnft.burn(1);
    //     //todo total supply is still 2!
    //     assertEq(ipnft.totalSupply(), 0);
    //     vm.stopPrank();
    // }

    function testFailCantMergeTokensThatYouDontOwn() public {
        vm.startPrank(alice);
        mintAToken(alice, "IP Title", arUri);
        ipnft.transferFrom(1, bob, 5);
        uint256[] memory tokenIdsToMerge = new uint256[](2);
        tokenIdsToMerge[0] = 2;
        tokenIdsToMerge[1] = 1;
        ipnft.merge(tokenIdsToMerge);
    }

    function testBurnMintedTokens() public {
        vm.startPrank(alice);
        mintAToken(alice, "IP Title", arUri);
        ipnft.burn(1);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 0);
    }

    function testFailBurnOwnedTokens() public {
        vm.startPrank(alice);
        mintAToken(alice, "IP Title", arUri);
        ipnft.transferFrom(1, bob, 500_000);
        vm.stopPrank();

        vm.startPrank(bob);
        assertEq(ipnft.ownerOf(2), bob);
        //todo only the minter (alice) can burn the token
        //see IPNFT3525V21::burn
        ipnft.burn(2);
        assertEq(ipnft.balanceOf(bob), 0);
        vm.stopPrank();
    }
}
