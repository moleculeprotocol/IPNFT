// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";
import { Metadata } from "../../src/IIPToken.sol";
import { IPToken } from "../../src/IPToken.sol";
import { WrappedIPToken } from "../../src/WrappedIPToken.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CommonScript } from "./Common.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DeployTokenizer is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        Tokenizer tokenizer = Tokenizer(address(new ERC1967Proxy(address(new Tokenizer()), "")));
        IPermissioner permissioner = IPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
        tokenizer.initialize(IPNFT(vm.envAddress("IPNFT_ADDRESS")), permissioner);

        IPToken initialIpTokenImplementation = new IPToken();
        tokenizer.setIPTokenImplementation(initialIpTokenImplementation);

        WrappedIPToken initialWrappedIpTokenImplementation = new WrappedIPToken();
        tokenizer.setWrappedIPTokenImplementation(initialWrappedIpTokenImplementation);

        vm.stopBroadcast();
        console.log("TOKENIZER_ADDRESS=%s", address(tokenizer));
        console.log("iptoken implementation=%s", address(initialIpTokenImplementation));
        console.log("wrapped iptoken implementation=%s", address(initialWrappedIpTokenImplementation));
    }
}

/**
 * @title FixtureTokenizer
 * @author
 * @notice execute Ipnft.s.sol && DeployTokenizer first
 * @notice assumes that bob (hh1) owns IPNFT#1
 */
contract FixtureTokenizer is CommonScript {
    Tokenizer tokenizer;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        tokenizer = Tokenizer(vm.envAddress("TOKENIZER_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function run() public {
        prepareAddresses();

        string memory terms = permissioner.specificTermsV1(Metadata(1, bob, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq"));

        vm.startBroadcast(bob);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        bytes memory signedTerms = abi.encodePacked(r, s, v);
        IPToken tokenContract =
            tokenizer.tokenizeIpnft(1, 1_000_000 ether, "MOLE", "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq", signedTerms);
        vm.stopBroadcast();

        console.log("IPTS_ADDRESS=%s", address(tokenContract));
    }
}
