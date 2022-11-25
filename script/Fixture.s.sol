// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT3525V2 } from "../src/IPNFT3525V2.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";

contract FixtureScript is Script {
    UUPSProxy proxy;
    IPNFT3525V2 ipnft;
    SchmackoSwap schmackoSwap;
    Mintpass mintpass;
    MyToken myToken;

    address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    address bob = vm.addr(vm.envUint("BOB_PRIVATE_KEY"));
    address alice = vm.addr(vm.envUint("ALICE_PRIVATE_KEY"));

    function supplyERC20Tokens(address to, uint256 amount) internal {
        vm.startBroadcast(deployer);
        myToken.mint(to, amount);
        vm.stopBroadcast();
    }

    function mintMintPass(address to) internal {
        vm.startBroadcast(deployer);
        mintpass.safeMint(to);
        vm.stopBroadcast();
    }

    function mintIpnft(address from, address to) internal returns(uint256) {
        vm.startBroadcast(from);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, "test", "testTokenURI");

        ipnft.mintReservation(to, reservationId);
        vm.stopBroadcast();
        return reservationId; 
    }

    function createListingAndSell(address from, address to, uint256 tokenId, uint256 price) internal {
        vm.startBroadcast(from);
        ipnft.approve(schmackoSwap, tokenId);
        uint256 listingId = schmackoSwap.list(ipnft, tokenId, myToken, price);
        schmackoSwap.changeBuyerAllowance(listingId, to, true);
        vm.stopBroadcast();

        supplyERC20Tokens(to, price);

        vm.startBroadcast(to);
        myToken.approve(address(schmackoSwap), price);
        schmackoSwap.fulfill(listingId);
        vm.stopBroadcast();
    }

    function run() public { 
         vm.startBroadcast(deployer);

        IPNFT3525V2 implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT3525V2(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        mintpass = new Mintpass(address(ipnft));
        myToken = new MyToken();
        vm.stopBroadcast();

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);
        createListingAndSell(bob, alice, tokenId, 10);
    }
}
