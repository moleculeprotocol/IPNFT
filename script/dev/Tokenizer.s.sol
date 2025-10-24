// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";
import { IIPToken } from "../../src/IIPToken.sol";
import { Metadata } from "../../src/IIPToken.sol";
import { IPToken } from "../../src/IPToken.sol";
import { WrappedIPToken } from "../../src/WrappedIPToken.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";

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

    function prepareAndSignTerms(uint256 tokenId) internal returns (bytes memory) {
        string memory terms = permissioner.specificTermsV1(Metadata(tokenId, bob, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        return abi.encodePacked(r, s, v);
    }

    function run() public {
        prepareAddresses();


        vm.startBroadcast(bob);
        bytes memory signedToken1Terms = prepareAndSignTerms(1);
        FakeERC20 usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));
        // Attach an already existing token as an IPT
        IIPToken token1Contract = tokenizer.attachIpt(1, "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq", signedToken1Terms, usdc);

        bytes memory signedToken2Terms = prepareAndSignTerms(2);

        // Mmint a new IPT
        IPToken token2Contract =
            tokenizer.tokenizeIpnft(2, 1_000_000 ether, "MOLE", "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq", signedToken2Terms);
        vm.stopBroadcast();

        console.log("ATTACHED_IPT_ADDRESS=%s", address(token1Contract));
        console.log("IPT_ADDRESS=%s", address(token2Contract));
    }
}
