// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

error InvalidSignature();
error Denied();

interface IPermissionable {
    function agreementCid() external returns (string memory);
}

interface IPermissioner {
    /**
     * @notice reverts when `_for` may not interact with `tokenContract`
     * @param permissionable IPermissionable
     * @param _for address
     * @param data bytes
     */
    function accept(IPermissionable permissionable, address _for, bytes calldata data) external;
}

contract BlindPermissioner is IPermissioner {
    function accept(IPermissionable tokenContract, address _for, bytes calldata data) external {
        //empty
    }
}

contract ForbidAllPermissioner is IPermissioner {
    function accept(IPermissionable, address, bytes calldata) external pure {
        revert Denied();
    }
}

contract TermsAcceptedPermissioner is IPermissioner {
    event TermsAccepted(address indexed tokenContract, address indexed signer, bytes signature);

    /**
     * @notice checks validity signer`'s `signature` of `specificTermsV1` on `tokenId` and emits an event
     *         reverts when `signature` can't be verified
     * @dev the signature itself or whether it has already been presented is not stored on chain
     *      uses OZ:`SignatureChecker` under the hood and also supports EIP1271 signatures
     *
     * @param permissionable IPermissionable
     * @param _for address the account that has created `signature`
     * @param signature bytes encoded signature, for eip155: `abi.encodePacked(r, s, v)`
     */
    function accept(IPermissionable permissionable, address _for, bytes calldata signature) external {
        if (!validateSignature(permissionable, _for, signature)) {
            revert InvalidSignature();
        }
        emit TermsAccepted(address(permissionable), _for, signature);
    }

    /**
     * @notice checks whether `signer`'s `signature` of `specificTermsV1` on `tokenContract.metadata.ipnftId` is valid
     * @param permissionable IPermissionable
     */
    function validateSignature(IPermissionable permissionable, address signer, bytes calldata signature) public view returns (bool) {
        bytes32 termsHash = MessageHashUtils.toEthSignedMessageHash(bytes(specificTerms(permissionable)));
        return SignatureChecker.isValidSignatureNow(signer, termsHash, signature);
    }

    function specificTerms(string memory agreementCid) public view returns (string memory) {
        return string.concat(
            "I have accepted all terms that I've read here: ipfs://",
            agreementCid,
            "\n\n",
            "Chain Id: ",
            Strings.toString(block.chainid),
            "\n",
            "Version: 1"
        );
    }

    /**
     * @notice this yields the message text that claimers must present to proof they have accepted all terms
     * @param permissionable IPermissionable
     */
    function specificTerms(IPermissionable permissionable) public returns (string memory) {
        return (specificTerms(permissionable.agreementCid()));
    }
}
