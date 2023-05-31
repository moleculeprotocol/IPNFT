// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/IPNFT.sol";

contract IPNFTScript is Script {
    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        IPNFT implementationV21 = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV21), "");
        IPNFT ipnftV2 = IPNFT(address(proxy));
        ipnftV2.initialize();
        vm.stopBroadcast();

        console.log("ipnftV2 address %s", address(implementationV21));
    }
}
