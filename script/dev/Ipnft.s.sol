// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { IPNFT } from "../../src/IPNFT.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { Mintpass } from "../../src/Mintpass.sol";
import { UUPSProxy } from "../../src/UUPSProxy.sol";
import { FakeERC20 } from "../../test/helpers/FakeERC20.sol";
import { IERC1155Supply } from "../../src/IERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployIpnft is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address deployer,) = deriveRememberKey(mnemonic, 0);
        vm.startBroadcast(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();
        FakeERC20 usdc = new FakeERC20("USDC Token", "USDC");

        Mintpass mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);

        ipnft.setAuthorizer(address(mintpass));

        console.log("ipnftv2 %s", address(ipnft));
        console.log("swap %s", address(swap));
        console.log("pass %s", address(mintpass));
        console.log("usdc %s", address(usdc));

        vm.stopBroadcast();
    }
}

contract FixtureIpnft is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    IPNFT ipnft;
    SchmackoSwap schmackoSwap;
    Mintpass mintpass;
    FakeERC20 usdc;

    address deployer;
    address bob;
    address alice;

    function prepareAddresses() internal {
        (deployer,) = deriveRememberKey(mnemonic, 0);
        (bob,) = deriveRememberKey(mnemonic, 1);
        (alice,) = deriveRememberKey(mnemonic, 2);

        ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));
        schmackoSwap = SchmackoSwap(vm.envAddress("SOS_ADDRESS"));
        mintpass = Mintpass(vm.envAddress("MINTPASS_ADDRESS"));
        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));
    }

    function dealERC20(address to, uint256 amount, FakeERC20 erc20) internal {
        vm.startBroadcast(deployer);
        erc20.mint(to, amount);
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

    function createListing(address seller, uint256 tokenId, uint256 price, FakeERC20 erc20) internal returns (uint256) {
        vm.startBroadcast(seller);
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId = schmackoSwap.list(IERC1155Supply(address(ipnft)), tokenId, IERC20(address(erc20)), price);
        vm.stopBroadcast();
        return listingId;
    }

    function run() public {
        prepareAddresses();

        mintMintPass(bob);

        uint256 tokenId = mintIpnft(bob, bob);

        dealERC20(bob, 1000 ether, usdc);
        dealERC20(alice, 1000 ether, usdc);

        uint256 listingId = createListing(bob, tokenId, 1 ether, usdc);
        //we're *NOT* accepting the listing here because of inconsistent listing ids on anvil
        //execute ApproveAndBuy.s.sol if you want to do that.
        console.log("listing id %s", listingId);
    }
}