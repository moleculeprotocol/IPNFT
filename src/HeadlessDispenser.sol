// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Mintpass } from "./Mintpass.sol";

/// @title Headless Dispenser
/// @author molecule.to
/// @notice if I get the Moderator role, I happily mint tokens to everyone. Made for testnets.
contract HeadlessDispenser {
    Mintpass private _mintpass;

    constructor(Mintpass mintpass) {
        _mintpass = mintpass;
    }

    ///@notice 5 max
    function dispense(uint256 amount) public {
        require(amount > 0 && amount < 6, "5 passes max, please");
        dispense(msg.sender, amount);
    }

    ///@notice 5 max
    function dispense(address to, uint256 amount) public {
        require(amount > 0 && amount < 6, "5 passes max, please");
        _mintpass.batchMint(to, amount);
    }
}
