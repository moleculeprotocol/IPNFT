// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap} from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";

contract DevScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        vm.startBroadcast();
        (address deployer, ) = deriveRememberKey(mnemonic, 0);
        vm.startBroadcast(deployer);
        IPNFT ipnft = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(ipnft), "");
        IPNFT ipnftV2 = IPNFT(address(proxy));
        ipnftV2.initialize();

        new SchmackoSwap();
        new MyToken();
        new Mintpass(address(ipnftV2));
        
        vm.stopBroadcast();
    }
}
