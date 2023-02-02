// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/IPNFT.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract IPNFTScript is Script {
    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT ipnftV2 = IPNFT(address(proxy));
        ipnftV2.initialize();
        vm.stopBroadcast();

        console.log("ipnftV2 address %s", address(ipnftV2));
    }
}
