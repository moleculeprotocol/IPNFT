// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IPToken } from "../../src/IPToken.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";
import { WrappedIPToken } from "../../src/WrappedIPToken.sol";
import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract RolloutTokenizerV14 is Script {
    function run() public {
        vm.startBroadcast();

        // Deploy new implementations
        IPToken ipTokenImplementation = new IPToken();
        WrappedIPToken wrappedIpTokenImplementation = new WrappedIPToken();
        Tokenizer newTokenizerImplementation = new Tokenizer();

        // Prepare upgrade call data using reinit function
        bytes memory upgradeCallData =
            abi.encodeWithSelector(Tokenizer.reinit.selector, address(wrappedIpTokenImplementation), address(ipTokenImplementation));

        console.log("IPTOKENIMPLEMENTATION=%s", address(ipTokenImplementation));
        console.log("WRAPPEDTOKENIMPLEMENTATION=%s", address(wrappedIpTokenImplementation));
        console.log("NEWTOKENIZER=%s", address(newTokenizerImplementation));
        console.log("UpgradeCallData:");
        console.logBytes(upgradeCallData);

        vm.stopBroadcast();
    }
}
