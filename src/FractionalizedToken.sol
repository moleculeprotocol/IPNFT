// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
/// @notice the owner of this contract is always the fractionalizer contract
contract FractionalizedTokenUpgradeable is IERC20Upgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    function initialize(string memory name, string memory symbol) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
    }

    function issue(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount);
    }
}
