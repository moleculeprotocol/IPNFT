// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Fractionalizer } from "../../src/Fractionalizer.sol";
import { FractionalizedToken } from "../../src/FractionalizedToken.sol";

import { DevScript } from "./Dev.s.sol";

/**
 * @title FractionalizeScript
 * @author
 * @notice execute Dev.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1
 */
contract FractionalizeScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    Fractionalizer fractionalizer;
    IPNFT ipnft;

    address deployer;
    address bob;
    address alice;

    function prepareAddresses() internal {
        (deployer,) = deriveRememberKey(mnemonic, 0);
        (bob,) = deriveRememberKey(mnemonic, 1);
        (alice,) = deriveRememberKey(mnemonic, 2);
    }

    function run() public {
        prepareAddresses();

        ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));
        fractionalizer = Fractionalizer(vm.envAddress("FRACTIONALIZER_ADDRESS"));

        vm.startBroadcast(bob);
        FractionalizedToken tokenContract =
            fractionalizer.fractionalizeIpnft(1, 1_000_000 ether, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq");
        vm.stopBroadcast();

        console.log("fraction fam erc20 address: %s", address(tokenContract));
        console.log("fraction hash: %s", tokenContract.hash());
    }
}
