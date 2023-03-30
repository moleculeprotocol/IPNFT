// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpdateFractionalizerL2 is Script {
    function run() public {
        vm.startBroadcast();
        //using the oGSN trusted forwarder for metatx here
        Fractionalizer fractionalizer = new Fractionalizer(0xB2b5841DBeF766d4b521221732F9B618fCf34A87);
        vm.stopBroadcast();

        console.log("new fractionalizer L2 logic at %s", address(fractionalizer));
    }
}
