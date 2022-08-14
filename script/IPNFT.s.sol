// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/IPNFT.sol";

contract IPNFTScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IPNFT nft = new IPNFT("Molecule IP-NFT Test", "IPNFT");
        vm.stopBroadcast();
    }
}
