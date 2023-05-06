// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

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
contract FractionalizedToken is IERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    //this will only go up.
    uint256 internal _totalIssued;

    Metadata internal _metadata;

    function initialize(string memory name, string memory symbol, Metadata calldata metadata_) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
        _metadata = metadata_;
        _totalIssued = 0;
    }

    function totalIssued() public view returns (uint256) {
        return _totalIssued;
    }

    function metadata() public view returns (Metadata memory) {
        return _metadata;
    }

    function issuer() public view returns (address) {
        return _metadata.originalOwner;
    }

    function fractionId() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_metadata.originalOwner, _metadata.ipnftId)));
    }

    /**
     * @dev this can only be called by the contract owner which is the `Fractionalizer` who creates it
     * @param receiver address
     * @param amount uint256
     */
    function issue(address receiver, uint256 amount) public onlyOwner {
        _totalIssued += amount;
        _mint(receiver, amount);
    }
}
