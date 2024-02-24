// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IAuthorizeMints } from "../../src/IAuthorizeMints.sol";

contract AcceptAllAuthorizer is IAuthorizeMints {
    function authorizeMint(address, address, bytes memory) external pure override returns (bool) {
        return true;
    }

    function authorizeReservation(address) external pure override returns (bool) {
        return true;
    }

    function redeem(bytes memory) external pure override {
        return;
    }
}
