// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { Mintpass } from "../../src/Mintpass.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { CommonScript } from "./Common.sol";

contract DeployIpnftSuite is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();

        Mintpass mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);

        ipnft.setAuthorizer(address(mintpass));

        console.log("IPNFT_ADDRESS=%s", address(ipnft));
        console.log("SOS_ADDRESS=%s", address(swap));
        console.log("MINTPASS_ADDRESS=%s", address(mintpass));

        vm.stopBroadcast();
    }
}

contract FixtureIpnft is CommonScript {
    IPNFT ipnft;
    SchmackoSwap schmackoSwap;
    Mintpass mintpass;
    FakeERC20 usdc;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        ipnft = IPNFT(vm.envAddress("IPNFT_ADDRESS"));
        schmackoSwap = SchmackoSwap(vm.envAddress("SOS_ADDRESS"));
        mintpass = Mintpass(vm.envAddress("MINTPASS_ADDRESS"));
        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));
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
        uint256 listingId = schmackoSwap.list(IERC721(address(ipnft)), tokenId, IERC20(address(erc20)), price);
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
