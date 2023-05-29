// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

struct Metadata {
    uint256 ipnftId;
    address originalOwner;
    string agreementCid;
}

error TokenCapped();
error OnlyIssuerOrOwner();

/**
 * @title FractionalizedToken
 * @author molecule.to
 * @notice this is a template contract that's spawned by the Fractionalizer
 * @notice the owner of this contract is always the Fractionalizer contract.
 *         the issuer of a token bears the right to increase the supply as long as the token is not capped.
 */
contract FractionalizedToken is ERC20BurnableUpgradeable, OwnableUpgradeable {
    event Capped(uint256 atSupply);

    //this will only go up.
    uint256 public totalIssued;
    /**
     * @notice when true, no one can ever mint tokens again.
     */
    bool public capped;
    Metadata internal _metadata;

    function initialize(string calldata name, string calldata symbol, Metadata calldata metadata_) external initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
        _metadata = metadata_;
    }

    modifier onlyIssuerOrOwner() {
        if (msg.sender != _metadata.originalOwner && msg.sender != owner()) {
            revert OnlyIssuerOrOwner();
        }
        _;
    }

    function issuer() external view returns (address) {
        return _metadata.originalOwner;
    }

    function metadata() external view returns (Metadata memory) {
        return _metadata;
    }
    /**
     * @notice Fractional tokens are identified by the original token holder and the underlying token id
     * @return uint256 a token hash that's unique for [`originaOwner`,`ipnftid`]
     */

    function hash() external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_metadata.originalOwner, _metadata.ipnftId)));
    }

    /**
     * @notice we deliberately allow the fraction initializer to increase the fraction supply at will as long as the underlying asset has not been sold yet
     * @param receiver address
     * @param amount uint256
     */
    function issue(address receiver, uint256 amount) external onlyIssuerOrOwner {
        if (capped) revert TokenCapped();
        totalIssued += amount;
        _mint(receiver, amount);
    }

    /**
     * @notice mark this token as capped. After calling this, no new tokens can be `issue`d
     */
    function cap() external onlyIssuerOrOwner {
        capped = true;
        emit Capped(totalIssued);
    }
}
