// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { SignatureMintAuthorizer } from "../../src/MintAuthorizer.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { CommonScript } from "./Common.sol";

struct SignedMintAuthorization {
    uint256 reservationId;
    string tokenUri;
    bytes signature;
}

contract DeployIpnftSuite is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();

        SignatureMintAuthorizer authorizer = new SignatureMintAuthorizer(
      0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    );

        ipnft.setAuthorizer(address(authorizer));

        console.log("IPNFT_ADDRESS=%s", address(ipnft));
        console.log("SOS_ADDRESS=%s", address(swap));
        console.log("SIGNATURE_AUTHORIZER_ADDRESS=%s", address(authorizer));

        vm.stopBroadcast();
    }
}

contract SignAuthorizationScript is CommonScript {
    SignedMintAuthorization signedMintAuthorization;
    bytes32 messageHash;

    function signAuthorization(address ipnft) internal returns (bytes memory) {
        signedMintAuthorization.reservationId = 1;
        signedMintAuthorization.tokenUri = "tokenURI";
        messageHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(alice, ipnft, signedMintAuthorization.reservationId, signedMintAuthorization.tokenUri))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(charliePk, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        signedMintAuthorization.signature = signature;
        return abi.encode(signedMintAuthorization);
    }
}

contract FixtureIpnft is SignAuthorizationScript {
    IPNFT ipnft;
    SchmackoSwap schmackoSwap;
    FakeERC20 usdc;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));
        schmackoSwap = SchmackoSwap(vm.envAddress("SOS_ADDRESS"));
        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));
    }

    function mintIpnft(address from, address to) internal returns (uint256) {
        vm.startBroadcast(from);
        uint256 reservationId = ipnft.reserve();
        bytes memory data = signAuthorization(address(ipnft));
        ipnft.mintReservation{ value: 0.001 ether }(to, reservationId, "ar://cy7I6VoEXhO5rHrq8siFYtelM9YZKyoGj3vmGwJZJOc", "BIO-00001", data);
        vm.stopBroadcast();
        return reservationId;
    }

    function createListing(address seller, uint256 tokenId, uint256 price, FakeERC20 erc20) internal returns (uint256) {
        vm.startBroadcast(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId = schmackoSwap.list(IERC721(address(ipnft)), tokenId, IERC20(address(erc20)), price);
        vm.stopBroadcast();
        return listingId;
    }

    function run() public {
        prepareAddresses();

        uint256 tokenId = mintIpnft(bob, bob);

        dealERC20(bob, 1000 ether, usdc);
        dealERC20(alice, 1000 ether, usdc);

        uint256 listingId = createListing(bob, tokenId, 1 ether, usdc);
        //we're *NOT* accepting the listing here because of inconsistent listing ids on anvil
        //execute ApproveAndBuy.s.sol if you want to do that.
        console.log("listing id %s", listingId);
    }
}
