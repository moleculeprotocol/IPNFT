// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import { Safe } from "safe-global/safe-contracts/Safe.sol";
import { SafeProxyFactory } from "safe-global/safe-contracts/proxies/SafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import { CompatibilityFallbackHandler } from "safe-global/safe-contracts/handler/CompatibilityFallbackHandler.sol";

library MakeGnosisWallet {
    function makeGnosisWallet(SafeProxyFactory factory, address[] memory owners) public returns (Safe) {
        Safe singleton = new Safe();

        Safe wallet = Safe(payable(factory.createProxyWithNonce(address(singleton), "", uint256(1680130687))));
        CompatibilityFallbackHandler fallbackHandler = new CompatibilityFallbackHandler();
        wallet.setup(owners, 1, address(0x0), "", address(fallbackHandler), address(0x0), 0, payable(address(0x0)));
        return wallet;
    }
}
