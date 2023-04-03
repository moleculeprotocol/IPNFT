// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { FractionalizerL2Dispatcher } from "../src/FractionalizerL2Dispatcher.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { ContractRegistry } from "../src/ContractRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployFractionalizerDispatcherL1 is Script {
    function run() public {
        SchmackoSwap schmackoSwap = SchmackoSwap(vm.envAddress("SOS_ADDRESS"));
        ContractRegistry contractRegistry = ContractRegistry(vm.envAddress("REGISTRY_ADDRESS"));

        vm.startBroadcast();
        FractionalizerL2Dispatcher fractionalizer = FractionalizerL2Dispatcher(
            address(
                new ERC1967Proxy(
                    address(
                        new FractionalizerL2Dispatcher()
                    ), ""
                )
            )
        );
        fractionalizer.initialize(schmackoSwap, contractRegistry);
        vm.stopBroadcast();

        console.log("fractionalizer L1 %s", address(fractionalizer));
    }
}
