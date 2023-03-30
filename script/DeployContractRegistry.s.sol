// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ContractRegistry, ContractRegistryGoerli, ContractRegistryMainnet } from "../src/ContractRegistry.sol";

contract DeployContractRegistry is Script {
    function run() public {
        vm.startBroadcast();
        uint256 network = vm.envUint("NETWORK");

        ContractRegistry registry;
        if (network == 5) {
            registry = new ContractRegistryGoerli();
        } else if (network == 1) {
            registry = new ContractRegistryMainnet();
        } else {
            revert("unsupported network");
        }

        console.log("registry L1 (%s): %s", network, address(registry));
        vm.stopBroadcast();
    }
}
