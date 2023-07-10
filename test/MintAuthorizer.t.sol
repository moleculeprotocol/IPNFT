// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { SignedMintAuthorizer, SignedMintAuthorization } from "../src/SignedMintAuthorizer.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MintAuthorizerTest is Test {
    SignedMintAuthorizer public authorizer;

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";

    address deployer = makeAddr("deployer");
    address ipnft = makeAddr("IPNFT");

    address alice;
    uint256 alicePk;

    address authorizedSigner;
    uint256 authorizedSignerPk;

    event Revoked(uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public {
        (authorizedSigner, authorizedSignerPk) = makeAddrAndKey("authorizedSigner");
        (alice, alicePk) = makeAddrAndKey("alice");

        vm.startPrank(deployer);
        authorizer = new SignedMintAuthorizer(authorizedSigner);
        vm.stopPrank();
    }

    function testAuthorizerAcceptsOnlyValidSignatures() public {
        bytes32 authMessageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(alice, alice, uint256(1), ipfsUri)));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorizedSignerPk, authMessageHash);

        SignedMintAuthorization memory authorization = SignedMintAuthorization(1, ipfsUri, abi.encodePacked(r, s, v));

        bool authorized = authorizer.authorizeMint(alice, alice, abi.encode(authorization));
        assertTrue(authorized);

        (v, r, s) = vm.sign(alicePk, authMessageHash);
        authorized = authorizer.authorizeMint(alice, alice, abi.encode(SignedMintAuthorization(1, ipfsUri, abi.encodePacked(r, s, v))));
        assertFalse(authorized);
    }
}
