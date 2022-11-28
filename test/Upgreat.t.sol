// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Upgreat } from "../src/Upgreat.sol";

contract UpgreatTest is Test {
    Upgreat public upgreat;

    address deployer = address(0x1);

    function setUp() public {
        vm.startPrank(deployer);
        upgreat = new Upgreat();
        upgreat.initialize();
        vm.stopPrank();
    }

    function testSpeak() public {
        assertEq(upgreat.speak(), "great");
    }
}
