// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MyToken.sol";
import "../src/IPNFT.sol";
import "../src/SchmackoSwap.sol";

contract IPNFTScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new IPNFT();
        new SchmackoSwap();
        new MyToken();
        vm.stopBroadcast();
    }
}
