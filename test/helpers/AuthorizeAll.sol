// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IAuthorizeMints } from "../../src/IAuthorizeMints.sol";

contract AuthorizeAll is IAuthorizeMints {
    function authorizeMint(address minter, address to, bytes memory data) external view returns (bool) {
        minter;
        to;
        data;
        return true;
    }

    /// @notice checks whether `reserver` is allowed to reserve a token id on the target contract
    function authorizeReservation(address reserver) external view returns (bool) {
        reserver;
        return true;
    }

    /// @notice called by the gated token contract to signal that a token has been minted and an authorization can be invalidated
    /// @param data implementation specific data
    function redeem(bytes memory data) external {
        data;
        //noop;
    }
}
