// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract DeployScript is Script {
    function run() public {
        address moderator = vm.envAddress("MODERATOR_ADDRESS");
        vm.startBroadcast();
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();
        Mintpass mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), moderator);

        ipnft.setAuthorizer(address(mintpass));

        console.log("ipnftv2 %s", address(ipnft));
        console.log("swap %s", address(swap));
        console.log("pass %s", address(mintpass));

        vm.stopBroadcast();
    }
}
