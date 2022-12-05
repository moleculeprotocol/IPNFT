// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IReservable {
    function reserve() external returns (uint256);
    function updateReservation(uint256 reservationId, bytes calldata newMetadata) external;
    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, bytes memory finalMetadata)
        external
        returns (uint256 slotId);
}
