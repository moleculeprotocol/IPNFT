// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IPNFT3525V21} from "../src/IPNFT3525V21.sol";
import {UUPSProxy} from "../src/UUPSProxy.sol";

contract IPNFT3525V21Test is Test {
    IPNFT3525V21 implementationV1;
    UUPSProxy proxy;
    IPNFT3525V21 ipnft;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        implementationV1 = new IPNFT3525V21();
        proxy = new UUPSProxy(address(implementationV1), "");
        ipnft = IPNFT3525V21(address(proxy));
        ipnft.initialize();
        vm.stopPrank();
    }

    function testContractName() public {
        assertEq(ipnft.name(), "IP-NFT V2.1");
    }

    function mintAToken(
        address to,
        string memory title,
        string memory description,
        string memory tokenUri,
        uint64 initialFractions
    ) internal {
        uint64[] memory fractions = new uint64[](1);
        fractions[0] = initialFractions;

        bytes memory ipnftArgs = abi.encode(
            title,
            description,
            tokenUri,
            fractions
        );

        ipnft.mint(to, ipnftArgs);
    }

    function mintAToken(
        address to,
        string memory title,
        string memory description,
        string memory tokenUri
    ) internal {
        mintAToken(to, title, description, tokenUri, 1);
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

    function testCanMintWithMoreThanOneFraction() public {
        uint64[] memory fractions = new uint64[](2);
        fractions[0] = 50;
        fractions[1] = 50;

        bytes memory ipnftArgs = abi.encode("", "", "", fractions);

        ipnft.mint(alice, ipnftArgs);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), alice);

        assertEq(ipnft.balanceOf(1), 50);
        assertEq(ipnft.balanceOf(2), 50);

        assertEq(ipnft.tokenSupplyInSlot(1), 2);
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

    function testSplitandMerge() public {
        mintAToken(alice, "", "", arUri, 10);

        assertEq(ipnft.balanceOf(1), 10);
        // https://docs.soliditylang.org/en/v0.8.17/types.html#array-literals
        uint256[] memory fractions = new uint256[](2);
        fractions[0] = 5;
        fractions[1] = 5;

        //this creates another NFT on the same slot:
        vm.startPrank(alice);
        assertEq(ipnft.tokenSupplyInSlot(1), 1);
        ipnft.split(1, fractions);

        assertEq(ipnft.balanceOf(1), 5);
        assertEq(ipnft.balanceOf(2), 5);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), alice);

        assertEq(ipnft.slotOf(1), 1);
        assertEq(ipnft.slotOf(2), 1);
        assertEq(ipnft.tokenSupplyInSlot(1), 2);

        //note the merge order matters: we're merging towards the last token id in the list.
        uint256[] memory tokenIdsToMerge = new uint256[](2);
        tokenIdsToMerge[0] = 2;
        tokenIdsToMerge[1] = 1;

        ipnft.merge(tokenIdsToMerge);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.balanceOf(1), 10);
        assertEq(ipnft.tokenSupplyInSlot(1), 1);
        vm.stopPrank();
    }

    function testTransferValueToANewUser() public {
        mintAToken(alice, "", "", arUri, 10);

        vm.startPrank(alice);
        //this is the ERC3525 value transfer not available on ERC721
        //fromTokenId, to, value
        //Bob will receive a new NFT by doing so.
        ipnft.transferFrom(1, bob, 5);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), bob);
        assertEq(ipnft.balanceOf(1), 5);
        assertEq(ipnft.balanceOf(2), 5);

        //that's because both tokens yield the slot's metadata:
        assertEq(ipnft.tokenURI(1), ipnft.tokenURI(2));

        //this would fail with NotApprovedOrOwner by ERC3525's _burn function
        // vm.startPrank(alice);
        // uint256[] memory tokenIdsToMerge = new uint256[](2);
        // tokenIdsToMerge[0] = 2;
        // tokenIdsToMerge[1] = 1;
        // ipnft.merge(tokenIdsToMerge);
        // vm.stopPrank();
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
