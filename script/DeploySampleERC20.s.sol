// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MyToken.sol";

contract DeploySampleERC20 is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new MyToken();
        vm.stopBroadcast();
    }
}
