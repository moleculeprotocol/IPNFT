// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { BioPriceFeed } from "../src/BioPriceFeed.sol";

contract DeployPricefeed is Script {
    function run() public {
        vm.startBroadcast();
        BioPriceFeed feed = new BioPriceFeed();
        vm.stopBroadcast();

        console.log("PRICEFEED_ADDRESS=%s", address(feed));
    }
}
