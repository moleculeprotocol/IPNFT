// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract UpgradeIpnft is Script {
    function run() public {
        vm.startBroadcast();
        address proxyAddr = vm.envAddress("IPNFT_ADDRESS");

        //this is not exactly an "IPNFT", it's rather the old implementation that we don't know here anymore
        //see IPNFTUpgrades.t.sol:testUpgradeContract
        IPNFT proxyIpnft = IPNFT(address(proxyAddr));
        //create a new implementation
        IPNFT newImpl = new IPNFT();
        proxyIpnft.upgradeTo(address(newImpl));

        console.log("new impl %s", address(newImpl));

        vm.stopBroadcast();
    }
}

contract DeployIpnftImpl is Script {
    function run() public {
        vm.startBroadcast();
        IPNFT newImpl = new IPNFT();
        console.log("new impl %s", address(newImpl));
        vm.stopBroadcast();
    }
}
