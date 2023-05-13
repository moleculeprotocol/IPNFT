// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { SalesShareDistributor } from "../src/SalesShareDistributor.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployShareDistributor is Script {
    function run() public {
        vm.startBroadcast();
        address sosAddress = vm.envAddress("SOS_ADDRESS");

        SalesShareDistributor impl = new SalesShareDistributor();

        SalesShareDistributor salesShareDistributor = SalesShareDistributor(
            address(
                new ERC1967Proxy(
                    address(impl), ""
                )
            )
        );
        salesShareDistributor.initialize(SchmackoSwap(sosAddress));
        vm.stopBroadcast();

        console.log("SalesShareDistributor %s", address(salesShareDistributor));
    }
}

contract DeploySalesShareDistributorImplementation is Script {
    function run() public {
        vm.startBroadcast();
        SalesShareDistributor impl = new SalesShareDistributor();
        vm.stopBroadcast();

        console.log("SalesShareDistributor impl %s", address(impl));
    }
}
