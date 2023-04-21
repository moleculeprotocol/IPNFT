// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployFractionalizer is Script {
    function run() public {
        vm.startBroadcast();
        address ipnftAddress = vm.envAddress("IPNFT_ADDRESS");
        address sosAddress = vm.envAddress("SOS_ADDRESS");

        Fractionalizer impl = new Fractionalizer();

        Fractionalizer fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(impl), ""
                )
            )
        );
        fractionalizer.initialize(IPNFT(ipnftAddress), SchmackoSwap(sosAddress));
        vm.stopBroadcast();

        console.log("fractionalizer L2 %s", address(fractionalizer));
    }
}
