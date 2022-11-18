// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IPNFT3525V2} from "../src/IPNFT3525V2.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";

contract IPNFT3525V2Test is Test {
    IPNFT3525V2 implementationV2;
    UUPSProxy proxy;
    IPNFT3525V2 ipnft;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT3525V2(address(proxy));
        ipnft.initialize();
        vm.stopPrank();
    }

    function testContractName() public {
        assertEq(ipnft.name(), "IP-NFT V2");
    }

    function mintAToken(
        address to,
        string memory title,
        string memory tokenUri
    ) internal {
        bytes memory ipnftArgs = abi.encode(title, tokenUri);

        ipnft.mint(to, ipnftArgs);
    }

    function testMinting() public {
        mintAToken(alice, "IP Title", arUri);

        assertEq(ipnft.totalSupply(), 1);
        string memory tokenUri_ = ipnft.tokenURI(1);

        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJleHRlcm5hbF91cmwiOiJhcjovL3ROYmRIcWgzQVZESFZEMDZQME9QVVhTUHJvSTVrR2NaWnc4SXZMa2VrU1kifQ=="
        );

        assertEq(ipnft.balanceOf(alice), 1);

        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);
    }

    function testTransferOneNft() public {
        mintAToken(alice, "", arUri);

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
        mintAToken(alice, "", arUri);

        assertEq(ipnft.slotOf(1), 1);

        string memory slotUri = ipnft.slotURI(1);
        assertEq(
            slotUri,
            "data:application/json;base64,eyJuYW1lIjoiIiwiZXh0ZXJuYWxfdXJsIjoiYXI6Ly90TmJkSHFoM0FWREhWRDA2UDBPUFVYU1Byb0k1a0djWlp3OEl2TGtla1NZIn0="
        );
    }

    function testFailTransferValueToANewUser() public {
        mintAToken(alice, "", arUri);

        vm.startPrank(alice);
        //this is the ERC3525 value transfer not available on ERC721
        //fromTokenId, to, value
        //Bob will receive a new NFT by doing so.
        ipnft.transferFrom(1, bob, 5);
        vm.stopPrank();
    }

    function testBurn() public {
        vm.startPrank(alice);
        mintAToken(alice, "", arUri);
        //todo actually alice can only burn the token
        //because she's marked as its minter. Currently only the
        //minter can burn their tokens.
        ipnft.burn(1);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 0);
    }

    function testApprovals() public {}
}
