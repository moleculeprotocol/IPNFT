// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPermissioner, BlindPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";

contract DeployPermissioners is Script {
    function run() public {
        vm.startBroadcast();
        IPermissioner p = new TermsAcceptedPermissioner();
        vm.stopBroadcast();
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(p));
    }
}
