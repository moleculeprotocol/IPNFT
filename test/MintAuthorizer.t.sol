// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { SignatureMintAuthorizer } from "../src/MintAuthorizer.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

struct SignedMintAuthorization {
    uint256 reservationId;
    string tokenUri;
    bytes signature;
}

contract MintAuthorizerTest is Test {
    SignatureMintAuthorizer public authorizer;
    SignedMintAuthorization signedMintAuthorization;
    address deployer = address(0x1);
    address ipnftContract = address(0x2);
    address alice = makeAddr("alice");
    uint256 alicePk;
    address authorizedSigner = makeAddr("authorizedSigner");
    uint256 authorizedSignerPk;
    address unauthorizedSigner = makeAddr("unauthorizedSigner");
    uint256 unauthorizedSignerPk;
    bytes32 messageHash;

    event Revoked(uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        signedMintAuthorization.reservationId = 1;
        signedMintAuthorization.tokenUri = "tokenURI";
        messageHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(alice, ipnftContract, signedMintAuthorization.reservationId, signedMintAuthorization.tokenUri))
        );
        vm.startPrank(deployer);
        authorizer = new SignatureMintAuthorizer(authorizedSigner);
        vm.stopPrank();
    }

    function testAuthorizeMint() public {
        (authorizedSigner, authorizedSignerPk) = makeAddrAndKey("authorizedSigner");
        vm.startPrank(deployer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorizedSignerPk, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        signedMintAuthorization.signature = signature;
        bytes memory data = abi.encode(signedMintAuthorization);
        bool authorized = authorizer.authorizeMint(alice, ipnftContract, data);
        vm.stopPrank();
        assertEq(authorized, true);
    }

    function testUnauthorizeMint() public {
        (unauthorizedSigner, unauthorizedSignerPk) = makeAddrAndKey("unauthorizedSigner");
        vm.startPrank(deployer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedSignerPk, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        signedMintAuthorization.signature = signature;
        bytes memory data = abi.encode(signedMintAuthorization);
        bool authorized = authorizer.authorizeMint(alice, ipnftContract, data);
        vm.stopPrank();
        assertEq(authorized, false);
    }
}
