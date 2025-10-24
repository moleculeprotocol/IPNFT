// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IIPToken, Metadata } from "./IIPToken.sol";
import { IPTokenUtils } from "./libraries/IPTokenUtils.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title WrappedIPToken
 * @author molecule.xyz
 * @notice A read-only wrapper that extends existing ERC20 tokens with IP metadata
 * @dev This contract provides IP metadata for an existing ERC20 token without proxying
 *      state-changing operations. It only implements IIPToken interface functions and
 *      read-only ERC20 view functions. Users must interact with the underlying token
 *      directly for transfers, approvals, and other state changes.
 */
contract WrappedIPToken is IIPToken, Initializable {
    IERC20Metadata public wrappedToken;

    Metadata internal _metadata;

    /**
     * @dev Initialize the contract with the provided parameters.
     * @param ipnftId the token id on the underlying nft collection
     * @param originalOwner the original owner of the ipnft
     * @param agreementCid a content hash that contains legal terms for IP token owners
     * @param wrappedToken_ the ERC20 token contract to wrap
     */
    function initialize(uint256 ipnftId, address originalOwner, string memory agreementCid, IERC20Metadata wrappedToken_) external initializer {
        _metadata = Metadata({ ipnftId: ipnftId, originalOwner: originalOwner, agreementCid: agreementCid });
        wrappedToken = wrappedToken_;
    }

    function metadata() external view override returns (Metadata memory) {
        return _metadata;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return wrappedToken.name();
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return wrappedToken.symbol();
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view returns (uint8) {
        return wrappedToken.decimals();
    }

    function totalSupply() public view returns (uint256) {
        return wrappedToken.totalSupply();
    }

    function balanceOf(address account) public view returns (uint256) {
        return wrappedToken.balanceOf(account);
    }

    function totalIssued() public view override returns (uint256) {
        return wrappedToken.totalSupply();
    }

    function issue(address, uint256) public virtual override {
        revert("WrappedIPToken: read-only wrapper - use underlying token for minting");
    }

    function cap() public virtual override {
        revert("WrappedIPToken: read-only wrapper - use underlying token for cappping");
    }

    function uri() external view override returns (string memory) {
        return IPTokenUtils.generateURI(_metadata, address(wrappedToken), wrappedToken.totalSupply());
    }
}
