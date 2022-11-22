// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap} from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";

contract DevScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IPNFT ipnft = new IPNFT();
        new SchmackoSwap();
        new MyToken();
        new Mintpass(address(ipnft));
        vm.stopBroadcast();
    }
}
