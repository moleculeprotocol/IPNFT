// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// TODO: Rename to "As a molecule holder..." and create new signatures
contract ReoverSigs is Test {
    function testRecoverManually() public {
        address _signer = 0x8FeEAAae1DB031E5F980F5E63fDbb277731e500e;
        string memory message =
            "As a fraction holder of IPNFT #10, I accept all terms that I've read here: 0x616e2061677265656d656e742068617368000000000000000000000000000000\n\nChain Id: 31337\nVersion: 1";
        bytes memory signature =
            hex"c4bbbf808b38943567915f2f5e6dc87a44d8e2f3f2fd298a850ea87bf632afd41c993814d8d69aacc9b0f438d05bfc58e99b3c09296dde3fb813fe18673fa98b1b";

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n169", message));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address signedBy = ecrecover(ethSignedMessageHash, v, r, s);
        console.logAddress(signedBy);
        assertEq(_signer, signedBy);
    }

    function testRecoverOz() public {
        address _signer = 0x8FeEAAae1DB031E5F980F5E63fDbb277731e500e;

        string memory message =
            "As a fraction holder of IPNFT #10, I accept all terms that I've read here: 0x616e2061677265656d656e742068617368000000000000000000000000000000\n\nChain Id: 31337\nVersion: 1";
        bytes memory signature =
            hex"c4bbbf808b38943567915f2f5e6dc87a44d8e2f3f2fd298a850ea87bf632afd41c993814d8d69aacc9b0f438d05bfc58e99b3c09296dde3fb813fe18673fa98b1b";
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(abi.encodePacked(message));
        bool isValid = SignatureChecker.isValidSignatureNow(_signer, ethSignedMessageHash, signature);

        console.log(isValid);
        assertTrue(isValid);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
