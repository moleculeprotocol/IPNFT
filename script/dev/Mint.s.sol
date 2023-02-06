// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../../src/MyToken.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { UUPSProxy } from "../../src/UUPSProxy.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { Mintpass } from "../../src/Mintpass.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DevScript } from "./Dev.s.sol";

contract MintScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    IPNFT ipnft = IPNFT(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    SchmackoSwap schmackoSwap = SchmackoSwap(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    Mintpass mintpass = Mintpass(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    MyToken myToken = MyToken(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);

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
        ipnft.mintReservation{value: 0.001 ether}(to, reservationId, 1, "ar://cy7I6VoEXhO5rHrq8siFYtelM9YZKyoGj3vmGwJZJOc");
        vm.stopBroadcast();
        return reservationId;
    }

    function createListing(address seller, uint256 tokenId, uint256 price) internal returns (uint256) {
        vm.startBroadcast(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), true);

        uint256 listingId = schmackoSwap.list(ERC1155Supply(address(ipnft)), tokenId, IERC20(address(myToken)), price);
        vm.stopBroadcast();
        return listingId;
    }

    function run() public {
        prepareAddresses();

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);

        dealERC20(bob, 1000 ether);
        dealERC20(alice, 1000 ether);

        uint256 listingId = createListing(bob, tokenId, 1 ether);
        console.log("listing id %s", listingId);
    }
}
