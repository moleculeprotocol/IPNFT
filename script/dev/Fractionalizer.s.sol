// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Fractionalizer } from "../../src/Fractionalizer.sol";
import { FractionalizedToken } from "../../src/FractionalizedToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CommonScript } from "./Common.sol";

contract DeployFractionalizer is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        Fractionalizer fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(new Fractionalizer()), ""
                )
            )
        );

        fractionalizer.initialize(IPNFT(vm.envAddress("IPNFT_ADDRESS")));
        vm.stopBroadcast();
        console.log("FRACTIONALIZER_ADDRESS=%s", address(fractionalizer));
    }
}

/**
 * @title FixtureFractionalizer
 * @author
 * @notice execute Ipnft.s.sol && DeployFractionalizer first
 * @notice assumes that bob (hh1) owns IPNFT#1
 */
contract FixtureFractionalizer is CommonScript {
    Fractionalizer fractionalizer;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        fractionalizer = Fractionalizer(vm.envAddress("FRACTIONALIZER_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function run() public {
        prepareAddresses();

        vm.startBroadcast(bob);
        FractionalizedToken tokenContract =
            fractionalizer.fractionalizeIpnft(1, 1_000_000 ether, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq");
        vm.stopBroadcast();

        console.log("fractionalized erc20 token address: %s", address(tokenContract));
        console.log("fraction hash: %s", tokenContract.hash());
    }
}
