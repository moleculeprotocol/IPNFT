// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";
import { IPToken } from "../../src/IPToken.sol";
import { console } from "forge-std/console.sol";

contract RolloutTokenizerV12 is Script {
    function run() public {
        vm.startBroadcast();

        IPToken newIpTokenImplementation = new IPToken();
        Tokenizer newTokenizerImplementation = new Tokenizer();

        bytes memory upgradeCallData = abi.encodeWithSelector(Tokenizer.setIPTokenImplementation.selector, address(newIpTokenImplementation));

        console.log("NEWTOKENIMPLEMENTATION=%s", address(newIpTokenImplementation));
        console.log("NEWTOKENIZER=%s", address(newTokenizerImplementation));
        console.logBytes(upgradeCallData);

        vm.stopBroadcast();
    }
}
