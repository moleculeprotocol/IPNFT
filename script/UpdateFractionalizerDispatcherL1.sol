// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { FractionalizerL2Dispatcher } from "../src/FractionalizerL2Dispatcher.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpdateFractionalizerDispatcherL1 is Script {
    function run() public {
        vm.startBroadcast();
        FractionalizerL2Dispatcher dispatcher = new FractionalizerL2Dispatcher();
        vm.stopBroadcast();

        console.log("new dispatcher L1 logic at %s", address(dispatcher));
    }
}
