// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/IPToken.sol";

contract DeployIPTokenImpl is Script {
    function run() external {
        vm.startBroadcast();
        IPToken iptoken = new IPToken();
        vm.stopBroadcast();

        console.log("new ip token implementation at %s", address(iptoken));
    }
}
