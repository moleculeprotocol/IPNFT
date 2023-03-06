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

contract DeployFractionalizerL2 is Script {
    function run() public {
        vm.startBroadcast();
        Fractionalizer fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Fractionalizer()
                    ), ""
                )
            )
        );
        fractionalizer.initialize();
        vm.stopBroadcast();

        console.log("fractionalizer L2 %s", address(fractionalizer));
    }
}
