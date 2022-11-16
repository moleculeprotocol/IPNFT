// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IPNFT3525} from "../src/IPNFT3525.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";

contract IPNFT3525Test is Test {
    IPNFT3525 implementationV1;
    UUPSProxy proxy;
    IPNFT3525 ipnft;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        implementationV1 = new IPNFT3525();
        proxy = new UUPSProxy(address(implementationV1), "");
        ipnft = IPNFT3525(address(proxy));
        ipnft.initialize();
        vm.stopPrank();
    }

    function testFoo() public {
        assertEq(ipnft.name(), "IP-NFT");
    }

    function mintAToken(
        address to,
        string memory title,
        string memory description,
        string memory tokenUri
    ) internal {
        uint64[] memory fractions = new uint64[](1);
        fractions[0] = 100;

        bytes memory ipnftArgs = abi.encode(
            title,
            description,
            tokenUri,
            fractions
        );

        ipnft.mint(to, ipnftArgs);
    }

    function testMinting() public {
        mintAToken(alice, "IP Title", "the description of that ip", arUri);

        assertEq(ipnft.totalSupply(), 1);
        string memory tokenUri_ = ipnft.tokenURI(1);

        //todo you obviously can't simply parse json in solidity. Add logic testing of this one to a hardhat test, maybe.
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJkZXNjcmlwdGlvbiI6InRoZSBkZXNjcmlwdGlvbiBvZiB0aGF0IGlwIiwiZXh0ZXJuYWxfdXJsIjoiYXI6Ly90TmJkSHFoM0FWREhWRDA2UDBPUFVYU1Byb0k1a0djWlp3OEl2TGtla1NZIn0="
        );

        assertEq(ipnft.balanceOf(alice), 1);

        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);
    }

    function testTransferOneNft() public {
        mintAToken(alice, "", "", arUri);

        vm.startPrank(alice);
        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.balanceOf(alice), 1);

        ipnft.safeTransferFrom(alice, bob, 1);
        assertEq(ipnft.ownerOf(1), bob);
        assertEq(ipnft.balanceOf(bob), 1);
        vm.stopPrank();

        //see if approvals also work
        vm.startPrank(bob);
        ipnft.approve(charlie, 1);

        //allowance is the fungible allowance on the value of a token.
        assertEq(ipnft.allowance(1, charlie), 0);
        vm.stopPrank();

        vm.startPrank(charlie);
        ipnft.safeTransferFrom(bob, alice, 1);
        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.balanceOf(bob), 0);
        vm.stopPrank();
    }

    //many NFTs can share the same slot
    //hence the slot "uri" yields the "basic" token Uri
    function testSlots() public {
        mintAToken(alice, "", "", arUri);

        assertEq(ipnft.slotOf(1), 1);

        string memory slotUri = ipnft.slotURI(1);
        assertEq(
            slotUri,
            "data:application/json;base64,eyJuYW1lIjoiIiwiZGVzY3JpcHRpb24iOiIiLCJleHRlcm5hbF91cmwiOiJhcjovL3ROYmRIcWgzQVZESFZEMDZQME9QVVhTUHJvSTVrR2NaWnc4SXZMa2VrU1kifQ=="
        );
    }

    function testBurn() public {
        vm.startPrank(alice);
        mintAToken(alice, "", "", arUri);
        //todo actually alice can only burn the token
        //because she's marked as its minter. Currently only the
        //minter can burn their tokens.
        ipnft.burn(1);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 0);
    }
}
