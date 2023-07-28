// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAuthorizeMints, SignedMintAuthorization } from "./IAuthorizeMints.sol";

/// @title SignedMintAuthorizer
/// @author molecule.to
contract SignedMintAuthorizer is IAuthorizeMints, Ownable {
    mapping(address => bool) trustedSigners;

    constructor(address initialSigner) Ownable() {
        trustedSigners[initialSigner] = true;
    }

    function trustSigner(address signer, bool trust) external onlyOwner {
        trustedSigners[signer] = trust;
    }

    /// @inheritdoc IAuthorizeMints
    /// @dev reverts when signature is not valid or recovered signer is not trusted
    //todo consider using an ERC712 typed signature here
    /// @param signedAuthorization contains encoded SignedMintAuthorization that a trusted signer has agreed upon
    function authorizeMint(address minter, address to, bytes memory signedAuthorization) external view override returns (bool) {
        SignedMintAuthorization memory auth = abi.decode(signedAuthorization, (SignedMintAuthorization));

        bytes32 signedHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(minter, to, auth.reservationId, auth.tokenUri)));

        (address signer,) = ECDSA.tryRecover(signedHash, auth.authorization);

        return trustedSigners[signer];
    }

    /// @inheritdoc IAuthorizeMints
    /// @dev this authorizer does not restrict reservations
    function authorizeReservation(address) external pure override returns (bool) {
        return true;
    }

    /// @inheritdoc IAuthorizeMints
    /// @dev this authorizer does not track redemptions
    function redeem(bytes memory) external pure override {
        return;
    }
}
