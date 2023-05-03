// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

struct Metadata {
    uint256 ipnftId;
    //needed to remember an individual's share after others burn their tokens
    address originalOwner;
    string agreementCid;
}

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
/// @notice the owner of this contract is always the fractionalizer contract
contract FractionalizedToken is IERC20Upgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    //this will only go up.
    uint256 public totalIssued;

    Metadata public metadata;

    function initialize(string memory name, string memory symbol, Metadata calldata _metadata) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
        metadata = _metadata;
        totalIssued = 0;
    }

    /**
     * @dev this can only be called by the contract owner which is the `Fractionalizer` who creates it
     * @param receiver address
     * @param amount uint256
     */
    function issue(address receiver, uint256 amount) public onlyOwner {
        totalIssued += amount;
        _mint(receiver, amount);
    }
}
