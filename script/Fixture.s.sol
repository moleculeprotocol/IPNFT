// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../src/MyToken.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        ipnft.mintReservation(to, reservationId, 1, "ar://cy7I6VoEXhO5rHrq8siFYtelM9YZKyoGj3vmGwJZJOc");
        vm.stopBroadcast();
        return reservationId;
    }

    function createListingAndSell(address seller, address buyer, uint256 tokenId, uint256 price) internal {
        vm.startBroadcast(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId = schmackoSwap.list(IERC1155Supply(address(ipnft)), tokenId, IERC20(address(myToken)), price);
        schmackoSwap.changeBuyerAllowance(listingId, buyer, true);
        vm.stopBroadcast();

        vm.startBroadcast(buyer);
        myToken.approve(address(schmackoSwap), price);
        schmackoSwap.fulfill(listingId);
        vm.stopBroadcast();
    }

    function run() public {
        prepareAddresses();

        vm.startBroadcast(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        myToken = new MyToken();
        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);

        ipnft.setAuthorizer(address(mintpass));

        console.log("ipnftv2 %s", address(ipnft));
        console.log("swap %s", address(schmackoSwap));
        console.log("token %s", address(myToken));
        console.log("pass %s", address(mintpass));

        vm.stopBroadcast();

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);

        dealERC20(bob, 1000 ether);
        dealERC20(alice, 1000 ether);

        createListingAndSell(bob, alice, tokenId, 1 ether);
    }
}
