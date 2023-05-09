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
contract DeployFractionalizer is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address deployer,) = deriveRememberKey(mnemonic, 0);
        (address bob,) = deriveRememberKey(mnemonic, 1);

        vm.startBroadcast(deployer);

        IPNFT ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));

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
        console.log("fractionalized erc20 token address: %s", address(tokenContract));
        console.log("fraction hash: %s", tokenContract.hash());
    }
}
