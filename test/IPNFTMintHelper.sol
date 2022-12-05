// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { IReservable } from "../src/IReservable.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

abstract contract IPNFTMintHelper is Test {
    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    string imageUrl = "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU";
    string agreementUrl = "ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json";
    string projectDetailsUrl = "ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json";

    bytes encodedMetadata = abi.encode("IP-NFT Test", "Some Description", imageUrl, agreementUrl, projectDetailsUrl);
    bytes updatedMetadata = abi.encode(
        "changed title", "Changed Description", "ar://abcde", "ar://defgh123/agree.json", "ipfs://mumumu/details.json"
    );

    Mintpass internal mintpass;

    address deployer = makeAddr("chucknorris");

    function reserveAToken(IReservable ipnft, address to, bytes memory metadata) internal returns (uint256) {
        dealMintpass(to);
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, metadata);
        vm.stopPrank();
        return reservationId;
    }

    function mintAToken(IReservable ipnft, address to) internal returns (uint256) {
        uint256 reservationId = reserveAToken(ipnft, to, encodedMetadata);
        vm.startPrank(to);
        ipnft.mintReservation(to, reservationId, 1, "");
        vm.stopPrank();
        return reservationId;
    }

    function dealMintpass(address to) internal {
        vm.startPrank(deployer);
        mintpass.batchMint(to, 1);
        vm.stopPrank();
    }
}
