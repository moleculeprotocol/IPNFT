// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IReservable {
    function reserve() external returns (uint256);
    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, string memory tokenURI)
        external
        payable
        returns (uint256 tokenId);
}
