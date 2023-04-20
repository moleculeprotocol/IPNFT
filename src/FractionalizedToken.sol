// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";
// import { IPNFT } from "./IPNFT.sol";

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
contract FractionalizedToken is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) { }
}
