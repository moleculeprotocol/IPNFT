// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IReservable } from "../src/IReservable.sol";
import { IAuthorizeMints } from "../src/IAuthorizeMints.sol";

abstract contract IPNFTMintHelper is Test {
    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    string imageUrl = "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU";

    address deployer = makeAddr("chucknorris");

    uint256 constant MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    function reserveAToken(IReservable ipnft, address to) internal returns (uint256) {
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();
        vm.stopPrank();
        return reservationId;
    }

    function mintAToken(IReservable ipnft, address to) internal returns (uint256) {
        return mintAToken(ipnft, to, "");
    }

    function mintAToken(IReservable ipnft, address to, bytes memory authorization) internal returns (uint256) {
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();

        ipnft.mintReservation{ value: MINTING_FEE }(to, reservationId, arUri, DEFAULT_SYMBOL, authorization);
        vm.stopPrank();
        return reservationId;
    }
}
