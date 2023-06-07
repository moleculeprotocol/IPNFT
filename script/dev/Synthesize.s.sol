// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Synthesizer } from "../../src/Synthesizer.sol";
import { Molecules } from "../../src/Molecules.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CommonScript } from "./Common.sol";

contract DeploySynthesizer is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        Synthesizer synthesizer = Synthesizer(
            address(
                new ERC1967Proxy(
                    address(new Synthesizer()), ""
                )
            )
        );

        synthesizer.initialize(IPNFT(vm.envAddress("IPNFT_ADDRESS")));
        vm.stopBroadcast();
        console.log("Synthesizer_ADDRESS=%s", address(synthesizer));
    }
}

/**
 * @title FixtureSynthesizer
 * @author
 * @notice execute Ipnft.s.sol && DeploySynthesizer first
 * @notice assumes that bob (hh1) owns IPNFT#1
 */
contract FixtureSynthesizer is CommonScript {
    Synthesizer synthesizer;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        synthesizer = Synthesizer(vm.envAddress("SYNTHESIZER_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function run() public {
        prepareAddresses();

        vm.startBroadcast(bob);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 1_000_000 ether, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq");
        vm.stopBroadcast();

        console.log("MOLECULES_ADDRESS=%s", address(tokenContract));
        console.log("molecules hash: %s", tokenContract.hash());
    }
}
