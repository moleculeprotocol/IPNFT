// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { HeadlessDispenser } from "../src/HeadlessDispenser.sol";

contract DeployDispenserScript is Script {
    function run() public {
        address _mintpass = vm.envAddress("MINTPASS_ADDRESS");
        Mintpass mintpass = Mintpass(_mintpass);

        vm.startBroadcast();
        HeadlessDispenser dispenser = new HeadlessDispenser(mintpass);
        mintpass.grantRole(mintpass.MODERATOR(), address(dispenser));
        vm.stopBroadcast();

        console.log("New Dispenser with MODERATOR role: %s", address(dispenser));
    }
}
