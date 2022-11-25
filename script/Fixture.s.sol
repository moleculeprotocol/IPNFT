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
    IPNFT3525V2 implementationV2;
    UUPSProxy proxy;
    IPNFT3525V2 ipnft;
    SchmackoSwap schmackoSwap;
    Mintpass mintpass;
    MyToken myToken;

    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    uint256 bob = vm.envUint("BOB_PRIVATE_KEY");
    uint256 alice = vm.envUint("ALIVE_PRIVATE_KEY");

    function supplyERC20Tokens(address to, uint256 amount) internal {
        vm.startBroadcast(deployerPrivateKey);
        myToken.mint(to, amount);
        vm.stopBroadcast();
    }

    function mintMintPass(address to) internal {
        vm.startBroadcast(deployerPrivateKey);
        mintpass.safeMint(to);
        vm.stopBroadcast();
    }

    function mintIpnft(address from, address to) internal {
        vm.startBroadcast(from);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, "test", "testTokenURI");

        ipnft.mintReservation(to, reservationId);
        vm.stopBroadcast();
    }

    function createListingAndSell(address from, address to, uint256 tokenId, uint256 price) internal {
        vm.startBroadcast(from);
        schmackoSwap.list(ipnft, tokenId, myToken, price);
        vm.stopBroadcast();

        // Add to allowlist


        // Buy Listing

    }

    function setUp() public {
        vm.startBroadcast(deployerPrivateKey);

        implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT3525V2(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        mintpass = new Mintpass(address(ipnft));
        myToken = new MyToken();
        vm.stopBroadcast();
    }


    function run() public { 
        setUp();
    }
}
