// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

struct IPNFT {
    uint256 totalUnits;
    uint16 version;
    string name;
    string description;
    string imageUrl;
    string agreementUrl;
    string projectDetailsUrl;
    address minter;
}

struct Reservation {
    address reserver;
    IPNFT ipnft;
}
