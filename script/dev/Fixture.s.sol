// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../../src/MyToken.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { UUPSProxy } from "../../src/UUPSProxy.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { Mintpass } from "../../src/Mintpass.sol";
import { IERC1155Supply } from "../../src/IERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DevScript } from "./Dev.s.sol";

/**
 * @title Fixtures
 * @author
 * @notice execute Dev.s.sol first
 */
contract FixtureScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    IPNFT ipnft;
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

    function dealERC20(address to, uint256 amount) internal {
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
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: 0.001 ether }(to, reservationId, 1, "ar://cy7I6VoEXhO5rHrq8siFYtelM9YZKyoGj3vmGwJZJOc", "BIO-00001");
        vm.stopBroadcast();
        return reservationId;
    }

    function createListing(address seller, uint256 tokenId, uint256 price) internal returns (uint256) {
        vm.startBroadcast(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId = schmackoSwap.list(IERC1155Supply(address(ipnft)), tokenId, IERC20(address(myToken)), price);
        vm.stopBroadcast();
        return listingId;
    }

    function run() public {
        prepareAddresses();

        ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));
        schmackoSwap = SchmackoSwap(vm.envAddress("SOS_ADDRESS"));
        myToken = MyToken(vm.envAddress("ERC20_ADDRESS"));
        mintpass = Mintpass(vm.envAddress("MINTPASS_ADDRESS"));

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);

        dealERC20(bob, 1000 ether);
        dealERC20(alice, 1000 ether);

        uint256 listingId = createListing(bob, tokenId, 1 ether);
        //we're *NOT* accepting the listing here because of inconsistent listing ids on anvil
        //execute ApproveAndBuy.s.sol if you want to do that.
        console.log("listing id %s", listingId);
    }
}
