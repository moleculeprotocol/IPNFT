// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT3525V2 } from "../src/IPNFT3525V2.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract IPNFTScript is Script {
    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        IPNFT3525V2 implementationV2 = new IPNFT3525V2();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT3525V2 ipnftV2 = IPNFT3525V2(address(proxy));
        ipnftV2.initialize();
    }
}
