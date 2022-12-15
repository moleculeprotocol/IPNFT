// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IAuthorizeMints {
    function authorizeMint(address minter, address to, bytes memory data) external view returns (bool);
    function authorizeReservation(address reserver) external view returns (bool);
    function redeem(bytes memory data) external;
}
