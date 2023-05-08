// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Fractionalizer } from "../../src/Fractionalizer.sol";
import { FractionalizedToken } from "../../src/FractionalizedToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


import { IpnftScript } from "./Ipnft.s.sol";

/**
 * @title FractionalizeScript
 * @author
 * @notice execute Ipnft.s.sol && Fixture.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1
 */
contract FractionalizeScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

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
        vm.startBroadcast(deployer);
        Fractionalizer fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(new Fractionalizer()), ""
                )
            )
        );
        fractionalizer.initialize(ipnft);
        vm.stopBroadcast();

        vm.startBroadcast(bob);
        FractionalizedToken tokenContract =
            fractionalizer.fractionalizeIpnft(1, 1_000_000 ether, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq");
        vm.stopBroadcast();

        console.log("frac %s", address(fractionalizer));
        console.log("fraction fam erc20 address: %s", address(tokenContract));
        console.log("fraction hash: %s", tokenContract.hash());

    }
}
