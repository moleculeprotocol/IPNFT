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

    address deployer = address(0x1);
    address bob = address(0x2);
    address alice = address(0x3);
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

    function testMinting() public {
        uint64[] memory fractions = new uint64[](1);
        fractions[0] = 100;

        bytes memory ipnftArgs = abi.encode(
            "IP Title",
            "the description of that ip",
            arUri,
            fractions
        );

        (string memory name_, , , uint64[] memory fractions_) = abi.decode(
            ipnftArgs,
            (string, string, string, uint64[])
        );

        assertEq(name_, "IP Title");
        assertEq(fractions_[0], 100);

        ipnft.mint(alice, ipnftArgs);

        string memory tokenUri_ = ipnft.tokenURI(1);

        //todo you obviously can't simply parse json in solidity. Add logic testing of this one to a hardhat test, maybe.
        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJkZXNjcmlwdGlvbiI6InRoZSBkZXNjcmlwdGlvbiBvZiB0aGF0IGlwIiwiZXh0ZXJuYWxfdXJsIjoiYXI6Ly90TmJkSHFoM0FWREhWRDA2UDBPUFVYU1Byb0k1a0djWlp3OEl2TGtla1NZIn0="
        );
    }
}
