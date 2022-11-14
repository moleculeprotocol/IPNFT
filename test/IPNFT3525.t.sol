// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IPNFT3525} from "../src/IPNFT3525.sol";

contract IPNFT3525Test is Test {
    IPNFT3525 public ipnftContract;

    address deployer = address(0x1);
    address bob = address(0x2);
    address alice = address(0x3);
    string testURI = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string testURI2 = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        ipnftContract = new IPNFT3525();
        ipnftContract.initialize();
        vm.stopPrank();
    }

    function testFoo() public {
        assertEq(ipnftContract.name(), "IP-NFT");
    }

    function testMinting() public {
        uint64[] memory fractions = new uint64[](1);
        fractions[0] = 100;

        bytes memory ipnftArgs = abi.encode(
            "some ip",
            "it's just some ip",
            "some uri",
            fractions
        );

        (string memory name_, , , uint64[] memory fractions_) = abi.decode(
            ipnftArgs,
            (string, string, string, uint64[])
        );

        assertEq(name_, "some ip", "thats an err");
        assertEq(fractions_[0], 100);

        ipnftContract.mint(alice, ipnftArgs);

        string memory tokenUri_ = ipnftContract.tokenURI(0);
        assertEq(tokenUri_, "token uri for 0");
    }
}
