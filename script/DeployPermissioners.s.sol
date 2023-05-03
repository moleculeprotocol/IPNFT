// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPermissioner, BlindPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";

contract DeployPermissioners is Script {
    function run() public {
        vm.startBroadcast();

        IPermissioner p = new TermsAcceptedPermissioner();
        IPermissioner bp = new BlindPermissioner();

        vm.stopBroadcast();

        console.log("BlindPermissioner %s", address(bp));
        console.log("TermsPermissioner %s", address(p));
    }
}
