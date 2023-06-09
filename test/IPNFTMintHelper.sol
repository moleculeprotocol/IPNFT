// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { IReservable } from "../src/IReservable.sol";

abstract contract IPNFTMintHelper is Test {
    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    string imageUrl = "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU";

    Mintpass internal mintpass;

    address deployer = makeAddr("chucknorris");

    uint256 constant MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    function dealMintpass(address to) internal {
        vm.startPrank(deployer);
        mintpass.batchMint(to, 1);
        vm.stopPrank();
    }

    function reserveAToken(IReservable ipnft, address to) internal returns (uint256) {
        dealMintpass(to);
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();
        vm.stopPrank();
        return reservationId;
    }

    function mintAToken(IReservable ipnft, address to) internal returns (uint256) {
        dealMintpass(to);
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();

        ipnft.mintReservation{ value: MINTING_FEE }(to, reservationId, reservationId, arUri, DEFAULT_SYMBOL);
        vm.stopPrank();
        return reservationId;
    }
}
