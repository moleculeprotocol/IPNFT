// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { FractionalizedToken } from "./FractionalizedToken.sol";

error InvalidSignature();

contract TermsAcceptedPermissioner {
    event TermsAccepted(address indexed tokenContract, address indexed signer, bytes signature);

    /**
     * @notice this yields the message text that claimers must present as signed message to burn their fractions and claim shares
     *
     * @param tokenContract FractionalizedToken
     */
    function specificTermsV1(FractionalizedToken tokenContract) public view returns (string memory) {
        (uint256 ipnftId,, string memory agreementCid) = tokenContract.metadata();

        return string(
            abi.encodePacked(
                "As a fraction holder of IPNFT #",
                Strings.toString(ipnftId),
                ", I accept all terms that I've read here: ipfs://",
                agreementCid,
                "\n\n",
                "Chain Id: ",
                Strings.toString(block.chainid),
                "\n",
                "Version: 1"
            )
        );
    }

    /**
     * @notice checks whether `signer`'s `signature` of `specificTermsV1` on `fractionId` is valid
     *
     * @param tokenContract FractionalizedToken
     */
    function isValidSignature(FractionalizedToken tokenContract, address signer, bytes memory signature) public view returns (bool) {
        bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(specificTermsV1(tokenContract)));
        return SignatureChecker.isValidSignatureNow(signer, termsHash, signature);
    }

    /**
     * @notice checks validity signer`'s `signature` of `specificTermsV1` on `fractionId` and emits an event
     * @dev the signature itself or whether it has already been presented is not stored on chain
     *
     * @param tokenContract FractionalizedToken
     * @param _for address the account that has created `signature`
     * @param signature bytes encoded signature, for eip155: `abi.encodePacked(r, s, v)`
     */
    function accept(FractionalizedToken tokenContract, address _for, bytes memory signature) public {
        if (!isValidSignature(tokenContract, _for, signature)) {
            revert InvalidSignature();
        }
        emit TermsAccepted(address(tokenContract), _for, signature);
    }
}
