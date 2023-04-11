// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SchmackoSwap.sol";

contract SchmackoSwapScript is Script {
    function setUp() public { }

    function run() public {
        vm.startBroadcast();
        SchmackoSwap sos = new SchmackoSwap();

        vm.stopBroadcast();
        console.log("Schmackoswap %s", address(sos));
    }
}
