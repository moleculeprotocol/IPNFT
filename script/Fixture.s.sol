// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT3525V2 } from "../src/IPNFT3525V2.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { IPNFTMetadata } from "../src/IPNFTMetadata.sol";

contract FixtureScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    UUPSProxy proxy;
    IPNFT3525V2 ipnftV2;
    SchmackoSwap schmackoSwap;
    Mintpass mintpass;
    MyToken myToken;

    address deployer;
    address bob;
    address alice;

    function prepareAddresses() internal {
        (deployer,) = deriveRememberKey(mnemonic, 0);
        (bob,) = deriveRememberKey(mnemonic, 1);
        (alice,) = deriveRememberKey(mnemonic, 2);
    }

    function supplyERC20Tokens(address to, uint256 amount) internal {
        vm.startBroadcast(deployer);
        myToken.mint(to, amount);
        vm.stopBroadcast();
    }

    function mintMintPass(address to) internal {
        vm.startBroadcast(deployer);
        mintpass.batchMint(to, 2);
        vm.stopBroadcast();
    }

    function mintIpnft(address from, address to) internal returns (uint256) {
        vm.startBroadcast(from);
        uint256 reservationId = ipnftV2.reserve();
        ipnftV2.updateReservation(
            reservationId,
            abi.encode(
                "IP-NFT Test",
                "Some Description",
                "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU",
                "ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json",
                "ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"
            )
        );
        ipnftV2.mintReservation(to, reservationId, 1, "");
        vm.stopBroadcast();
        return reservationId;
    }

    function createListingAndSell(address from, address to, uint256 tokenId, uint256 price) internal {
        vm.startBroadcast(from);
        ipnftV2.approve(address(schmackoSwap), tokenId);
        uint256 listingId = schmackoSwap.list(ipnftV2, tokenId, myToken, price);
        schmackoSwap.changeBuyerAllowance(listingId, to, true);
        vm.stopBroadcast();

        supplyERC20Tokens(to, price);

        vm.startBroadcast(to);
        myToken.approve(address(schmackoSwap), price);
        schmackoSwap.fulfill(listingId);
        vm.stopBroadcast();
    }

    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);

        IPNFT3525V2 implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnftV2 = IPNFT3525V2(address(proxy));
        ipnftV2.initialize();

        schmackoSwap = new SchmackoSwap();
        myToken = new MyToken();
        mintpass = new Mintpass(address(ipnftV2));

        ipnftV2.setMetadataGenerator(new IPNFTMetadata());
        ipnftV2.setMintpassContract(address(mintpass));

        console.log("ipnftv2 %s", address(ipnftV2));
        console.log("swap %s", address(schmackoSwap));
        console.log("token %s", address(myToken));
        console.log("pass %s", address(mintpass));

        vm.stopBroadcast();

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);
        createListingAndSell(bob, alice, tokenId, 10);
    }
}