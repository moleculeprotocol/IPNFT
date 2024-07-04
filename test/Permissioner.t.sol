// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { InvalidSignature, IPermissioner, TermsAcceptedPermissioner, BlindPermissioner } from "../src/Permissioner.sol";
import { IPToken, Metadata } from "../src/IPToken.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Safe } from "safe-global/safe-contracts/Safe.sol";
import { SafeProxyFactory } from "safe-global/safe-contracts/proxies/SafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import { MustOwnIpnft, AlreadyTokenized, Tokenizer, ZeroAddress } from "../src/Tokenizer.sol";

import "./helpers/MakeGnosisWallet.sol";

contract PermissionerTest is Test {
    address deployer = makeAddr("chucknorris");
    address originalOwner = makeAddr("daoMultisig");

    //Alice, Bob  are ipToken holders
    address alice = makeAddr("alice");
    uint256 alicePk;
    address bob = makeAddr("bob");
    uint256 bobPk;

    IPToken ipToken;
    TermsAcceptedPermissioner internal permissioner;

    uint256 MINTING_FEE = 0.001 ether;
    string agreementCid = "bafkrei";

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");

        vm.startPrank(deployer);
        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        Tokenizer tokenizer = Tokenizer(address(new ERC1967Proxy(address(new Tokenizer()), "")));
        tokenizer.initialize(ipnft, new BlindPermissioner());
        tokenizer.setIPTokenImplementation(new IPToken());
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.deal(originalOwner, MINTING_FEE);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, "", "", "");
        ipToken = tokenizer.tokenizeIpnft(1, 100_000, "IPT", agreementCid, "");
        vm.stopPrank();

        vm.startPrank(deployer);
        permissioner = new TermsAcceptedPermissioner();
        vm.store(address(tokenizer), bytes32(uint256(3)), bytes32(uint256(uint160(address(permissioner)))));
        vm.stopPrank();
    }

    function testProveSigAndAcceptTerms() public {
        vm.startPrank(originalOwner);

        string memory terms = permissioner.specificTermsV1(ipToken);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));

        bytes memory xsignature = abi.encodePacked(r, s, v);
        assertTrue(permissioner.isValidSignature(ipToken, alice, xsignature));

        vm.expectRevert(InvalidSignature.selector);
        permissioner.accept(ipToken, originalOwner, xsignature);
        vm.stopPrank();

        vm.startPrank(alice);
        permissioner.accept(ipToken, alice, xsignature);
        vm.stopPrank();
    }

    function testThatContractSignaturesAreAccepted() public {
        vm.startPrank(deployer);
        SafeProxyFactory fac = new SafeProxyFactory();
        vm.stopPrank();

        vm.startPrank(alice);
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;
        Safe wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
        vm.stopPrank();

        CompatibilityFallbackHandler fallbackHandler = new CompatibilityFallbackHandler();
        bytes32 messagehash = fallbackHandler.getMessageHashForSafe(
            wallet, abi.encodePacked(ECDSA.toEthSignedMessageHash(abi.encodePacked(permissioner.specificTermsV1(ipToken))))
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(alicePk, messagehash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bobPk, messagehash);

        bytes memory signature = bytes.concat(abi.encodePacked(r1, s1, v1), abi.encodePacked(r2, s2, v2));

        assertTrue(permissioner.isValidSignature(ipToken, address(wallet), signature));

        vm.startPrank(alice);
        permissioner.accept(ipToken, address(wallet), signature);
        vm.stopPrank();
    }
}
