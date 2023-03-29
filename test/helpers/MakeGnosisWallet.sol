// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { GnosisSafeL2 } from "safe-global/safe-contracts/GnosisSafeL2.sol";
import { GnosisSafeProxyFactory } from "safe-global/safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import { DefaultCallbackHandler } from "safe-global/safe-contracts/handler/DefaultCallbackHandler.sol";
//import { CompatibilityFallbackHandler } from "safe-global/safe-contracts/handler/CompatibilityFallbackHandler.sol";

library MakeGnosisWallet {
    function makeGnosisWallet(GnosisSafeProxyFactory factory, address[] memory owners) public returns (GnosisSafeL2) {
        GnosisSafeL2 singleton = new GnosisSafeL2();

        GnosisSafeL2 wallet = GnosisSafeL2(payable(factory.createProxyWithNonce(address(singleton), "", uint256(1680130687))));
        //DefaultCallbackHandler fallbackHandler = DefaultCallbackHandler(new CompatibilityFallbackHandler());
        DefaultCallbackHandler fallbackHandler = new DefaultCallbackHandler();
        wallet.setup(owners, 1, address(0x0), "", address(fallbackHandler), address(0x0), 0, payable(address(0x0)));
        return wallet;
    }
}
