// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
// import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
// import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// import { IPNFT } from "./IPNFT.sol";

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer

contract FractionalizedToken is IERC20, ERC20Burnable, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable() { }

    function issue(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount);
    }
}