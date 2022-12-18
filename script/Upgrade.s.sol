// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV21 } from "../src/IPNFTV21.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract UpgradeScript is Script {
    function run() public {
        vm.startBroadcast();
        address ipnftAddress = address(0x36444254795ce6E748cf0317EEE4c4271325D92A);
        IPNFT ipnft = IPNFT(ipnftAddress);

        IPNFTV21 ipnftv21 = new IPNFTV21();
        ipnft.upgradeTo(address(ipnftv21));
        vm.stopBroadcast();
    }
}
