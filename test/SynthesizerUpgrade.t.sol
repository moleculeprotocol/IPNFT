// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Base64Url } from "base64/Base64Url.sol";

import { Strings } from "./helpers/Strings.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { MustOwnIpnft, AlreadyTokenized, Tokenizer } from "../src/Tokenizer.sol";

import { IPToken, Metadata as IPTMetadata, OnlyIssuerOrOwner, TokenCapped } from "../src/IPToken.sol";
import { Molecules, Metadata as MoleculeMetadata } from "../src/helpers/test-upgrades/Molecules.sol";
import { Synthesizer } from "../src/helpers/test-upgrades/Synthesizer.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import {
    IPermissioner as OldIPermissioner,
    TermsAcceptedPermissioner as OldTermsAcceptedPermissioner
} from "../src/helpers/test-upgrades/SynthPermissioner.sol";

import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";

struct IPTMetadataProps {
    string agreement_content;
    address erc20_contract;
    uint256 ipnft_id;
    address original_owner;
    string supply;
}

struct IPTUriMetadata {
    uint256 decimals;
    string description;
    string external_url;
    string image;
    string name;
    IPTMetadataProps properties;
}

contract SynthesizerUpgradeTest is Test {
    using SafeERC20Upgradeable for IPToken;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    uint256 originalOwnerPk;

    //Alice, Bob and Charlie are molecules holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    uint256 bobPk;
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Synthesizer internal synthesizer;
    OldTermsAcceptedPermissioner internal oldTermsPermissioner;

    FakeERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (originalOwner, originalOwnerPk) = makeAddrAndKey("daoMultisig");

        vm.startPrank(deployer);

        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        erc20 = new FakeERC20('Fake ERC20', 'FERC');
        //erc20.mint(ipnftBuyer, 1_000_000 ether);

        oldTermsPermissioner = new OldTermsAcceptedPermissioner();

        synthesizer = Synthesizer(address(new ERC1967Proxy(address(new Synthesizer()), "")));
        synthesizer.initialize(ipnft, oldTermsPermissioner);

        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
        vm.stopPrank();
    }

    function testCanUpgradeErc20TokenImplementation() public {
        vm.startPrank(deployer);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        MoleculeMetadata memory oldMetadata = MoleculeMetadata(1, originalOwner, agreementCid);
        string memory terms = oldTermsPermissioner.specificTermsV1(oldMetadata);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(originalOwnerPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        bytes memory xsignature = abi.encodePacked(r, s, v);

        Molecules tokenContractOld = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, xsignature);
        vm.stopPrank();

        vm.startPrank(deployer);
        Tokenizer tokenizerImpl = new Tokenizer();

        synthesizer.upgradeTo(address(tokenizerImpl));

        Tokenizer tokenizer = Tokenizer(address(synthesizer));

        TermsAcceptedPermissioner termsPermissioner = new TermsAcceptedPermissioner();
        tokenizer.reinit(termsPermissioner);
        vm.stopPrank();

        assertEq(tokenContractOld.balanceOf(originalOwner), 100_000);

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
        IPTMetadata memory newMetadata = IPTMetadata(2, originalOwner, agreementCid);

        terms = termsPermissioner.specificTermsV1(newMetadata);
        (v, r, s) = vm.sign(originalOwnerPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        xsignature = abi.encodePacked(r, s, v);
        IPToken tokenContractNew = tokenizer.tokenizeIpnft(2, 70_000, "FAST", agreementCid, xsignature);
        vm.stopPrank();

        assertEq(tokenContractNew.balanceOf(originalOwner), 70_000);

        vm.startPrank(originalOwner);
        tokenContractOld.issue(originalOwner, 50_000);
        assertEq(tokenContractOld.balanceOf(originalOwner), 150_000);

        tokenContractNew.issue(originalOwner, 30_000);
        assertEq(tokenContractNew.balanceOf(originalOwner), 100_000);
        vm.stopPrank();

        string memory encodedUri = tokenContractOld.uri();
        IPTUriMetadata memory parsedMetadata =
            abi.decode(vm.parseJson(string(Base64Url.decode(Strings.substring(encodedUri, 29, bytes(encodedUri).length)))), (IPTUriMetadata));
        assertEq(parsedMetadata.name, "Molecules of IPNFT #1");

        encodedUri = tokenContractNew.uri();
        parsedMetadata =
            abi.decode(vm.parseJson(string(Base64Url.decode(Strings.substring(encodedUri, 29, bytes(encodedUri).length)))), (IPTUriMetadata));
        assertEq(parsedMetadata.name, "IP Tokens of IPNFT #2");
    }
}
