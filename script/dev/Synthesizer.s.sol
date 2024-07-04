// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

import { IPNFT } from "../../src/IPNFT.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";
import { Metadata, IPToken } from "../../src/IPToken.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";

import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { Synthesizer } from "../../src/helpers/test-upgrades/Synthesizer.sol";

import { Metadata as MolMetadata, Molecules } from "../../src/helpers/test-upgrades/Molecules.sol";
import {
    IPermissioner as IMolPermissioner,
    TermsAcceptedPermissioner as MolTermsAcceptedPermissioner
} from "../../src/helpers/test-upgrades/SynthPermissioner.sol";

import { CommonScript } from "./Common.sol";

/**
 * @title DeploySynthesizer
 * @notice only used for local testing. The "Synthesizer" is the old name for `Tokenizer`.
 */
contract DeploySynthesizer is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        Synthesizer synthesizer = Synthesizer(address(new ERC1967Proxy(address(new Synthesizer()), "")));
        MolTermsAcceptedPermissioner oldPermissioner = new MolTermsAcceptedPermissioner();

        synthesizer.initialize(IPNFT(vm.envAddress("IPNFT_ADDRESS")), oldPermissioner);
        vm.stopBroadcast();
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(oldPermissioner));
        console.log("SYNTHESIZER_ADDRESS=%s", address(synthesizer));
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
    MolTermsAcceptedPermissioner oldPermissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        synthesizer = Synthesizer(vm.envAddress("SYNTHESIZER_ADDRESS"));
        oldPermissioner = MolTermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function run() public {
        prepareAddresses();

        string memory terms = oldPermissioner.specificTermsV1(MolMetadata(1, bob, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq"));

        vm.startBroadcast(bob);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        bytes memory signedTerms = abi.encodePacked(r, s, v);
        Molecules tokenContract =
            synthesizer.synthesizeIpnft(1, 1_000_000 ether, "MOLE", "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq", signedTerms);
        vm.stopBroadcast();

        console.log("IPTS_ADDRESS=%s", address(tokenContract));
        console.log("ipts (molecules) round hash: %s", tokenContract.hash());
    }
}

/**
 * @notice allows testing contract upgrades on the frontend in a controlled way
 */
contract UpgradeSynthesizerToTokenizer is CommonScript {
    function run() public {
        prepareAddresses();
        Synthesizer synthesizer = Synthesizer(vm.envAddress("SYNTHESIZER_ADDRESS"));

        vm.startBroadcast(deployer);
        Tokenizer tokenizerImpl = new Tokenizer();
        synthesizer.upgradeTo(address(tokenizerImpl));
        Tokenizer tokenizer = Tokenizer(address(synthesizer));

        TermsAcceptedPermissioner newTermsPermissioner = new TermsAcceptedPermissioner();
        //todo tokenizer.reinit(newTermsPermissioner);
        vm.stopBroadcast();

        console.log("TOKENIZER_ADDRESS=%s", address(tokenizer)); //should equal synthesizer
        console.log("NEW_TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(newTermsPermissioner));
    }
}
