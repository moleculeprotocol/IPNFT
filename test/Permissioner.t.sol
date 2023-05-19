// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { InvalidSignature, IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import { FractionalizedToken, Metadata } from "../src/FractionalizedToken.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { Safe } from "safe-global/safe-contracts/Safe.sol";
import { SafeProxyFactory } from "safe-global/safe-contracts/proxies/SafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";

import "./helpers/MakeGnosisWallet.sol";

contract PermissionerTest is Test {
    address deployer = makeAddr("chucknorris");
    address originalOwner = makeAddr("daoMultisig");

    //Alice, Bob  are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;
    address bob = makeAddr("bob");
    uint256 bobPk;

    FractionalizedToken fracToken;
    TermsAcceptedPermissioner internal permissioner;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        vm.startPrank(deployer);
        permissioner = new TermsAcceptedPermissioner();

        fracToken = new FractionalizedToken();
        Metadata memory md = Metadata(1, originalOwner, "abcde");
        fracToken.initialize("foo", "BAR", md);

        vm.stopPrank();
    }

    function testProveSigAndAcceptTerms() public {
        vm.startPrank(originalOwner);

        string memory terms = permissioner.specificTermsV1(fracToken);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));

        bytes memory xsignature = abi.encodePacked(r, s, v);
        assertTrue(permissioner.isValidSignature(fracToken, alice, xsignature));

        vm.expectRevert(InvalidSignature.selector);
        permissioner.accept(fracToken, originalOwner, xsignature);
        vm.stopPrank();

        vm.startPrank(alice);
        permissioner.accept(fracToken, alice, xsignature);
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
            wallet, abi.encodePacked(ECDSA.toEthSignedMessageHash(abi.encodePacked(permissioner.specificTermsV1(fracToken))))
        );

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(alicePk, messagehash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(bobPk, messagehash);

        bytes memory signature = bytes.concat(abi.encodePacked(r1, s1, v1), abi.encodePacked(r2, s2, v2));

        assertTrue(permissioner.isValidSignature(fracToken, address(wallet), signature));

        vm.startPrank(alice);
        permissioner.accept(fracToken, address(wallet), signature);
        vm.stopPrank();
    }
}
