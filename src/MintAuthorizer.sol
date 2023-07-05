// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "erc721b/extensions/ERC721BBaseTokenURI.sol";
import "erc721b/extensions/ERC721BBurnable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAuthorizeMints } from "./IAuthorizeMints.sol";

struct SignedMintAuthorization {
    uint256 reservationId;
    string tokenUri;
    bytes signature;
}

/// @title SignatureMintAuthorizer
/// @author molecule.to
contract SignatureMintAuthorizer is IAuthorizeMints, Ownable {
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
    /// @param data contains encoded data that a trusted signer has agreed upon
    function authorizeMint(address minter, address to, bytes memory data) external view returns (bool) {
        SignedMintAuthorization memory auth = abi.decode(data, (SignedMintAuthorization));

        bytes32 signedHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(minter, to, auth.reservationId, auth.tokenUri)));

        (address signer,) = ECDSA.tryRecover(signedHash, auth.signature);
        return trustedSigners[signer];
    }

    /// @inheritdoc IAuthorizeMints
    /// @dev this authorizer does not restrict reservations
    function authorizeReservation(address) external view override returns (bool) {
        return true;
    }

    function redeem(bytes memory) external override {
        return;
    }
}
