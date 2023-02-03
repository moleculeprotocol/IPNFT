// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../../src/MyToken.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { Mintpass } from "../../src/Mintpass.sol";
import { UUPSProxy } from "../../src/UUPSProxy.sol";

contract DevScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address deployer,) = deriveRememberKey(mnemonic, 0);
        vm.startBroadcast(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();
        MyToken token = new MyToken();
        Mintpass mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);

        ipnft.setAuthorizer(address(mintpass));

        console.log("ipnftv2 %s", address(ipnft));
        console.log("swap %s", address(swap));
        console.log("token %s", address(token));
        console.log("pass %s", address(mintpass));

        vm.stopBroadcast();
    }
}
