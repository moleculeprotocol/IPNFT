// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Fractionalizer, InsufficientBalance } from "./Fractionalizer.sol";

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
/// @notice the owner of this contract is always the fractionalizer contract
contract FractionalizedTokenUpgradeable is IERC20Upgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 fractionId;

    event SharesClaimed(uint256 indexed fractionId, address indexed claimer, uint256 amount);

    function initialize(string memory name, string memory symbol, uint256 _fractionId) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
        fractionId = _fractionId;
    }

    function issue(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount);
    }

    /**
     * @notice call during claiming phase to burn all fractions and receive the pro rata sales share
     * @param signature bytes a `isValidSignature` by the sender that signs `specificTermsV1`
     */
    function burn(bytes memory signature) public {
        uint256 balance = balanceOf(_msgSender());
        if (balance == 0) {
            revert InsufficientBalance();
        }

        Fractionalizer fractionalizer = Fractionalizer(owner());
        fractionalizer.acceptTerms(fractionId, _msgSender(), signature);

        (IERC20 paymentToken, uint256 erc20shares) = fractionalizer.claimableTokens(fractionId, _msgSender());
        if (erc20shares == 0) {
            //todo: this is very hard to simulate because the condition above will already yield 0
            revert InsufficientBalance();
        }
        emit SharesClaimed(fractionId, _msgSender(), balance);
        super._burn(_msgSender(), balance);
        paymentToken.safeTransfer(_msgSender(), erc20shares);
    }
}
