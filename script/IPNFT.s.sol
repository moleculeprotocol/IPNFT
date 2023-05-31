// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/IPNFT.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast();
        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        vm.stopBroadcast();

        console.log("IPNFT_ADDRESS=%s", address(ipnft));
    }
}

contract Upgrade is Script {
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
