// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { BioPriceFeed } from "../src/BioPriceFeed.sol";
import { IPermissioner, BlindPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";

import { CommonScript } from "./dev/Common.sol";

contract DeployPeriphery is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        BioPriceFeed feed = new BioPriceFeed();
        IPermissioner p = new TermsAcceptedPermissioner();
        vm.stopBroadcast();

        console.log("PRICEFEED_ADDRESS=%s", address(feed));
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(p));
    }
}
