// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IIPToken, Metadata } from "./IIPToken.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title WrappedIPToken
 * @author molecule.xyz
 * @notice this is a template contract that's cloned by the Tokenizer
 * @notice this contract is used to wrap an ERC20 token and extend its metadata
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
    function name() public view override returns (string memory) {
        return wrappedToken.name();
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return wrappedToken.symbol();
    }

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() public view override returns (uint8) {
        return wrappedToken.decimals();
    }

    function totalIssued() public view override returns (uint256) {
        return wrappedToken.totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        return wrappedToken.balanceOf(account);
    }

    function issue(address, uint256) public virtual override {
        revert("WrappedIPToken: cannot issue");
    }

    function cap() public virtual override {
        revert("WrappedIPToken: cannot cap");
    }

    function uri() external view override returns (string memory) {
        string memory tokenId = Strings.toString(_metadata.ipnftId);

        string memory props = string.concat(
            '"properties": {',
            '"ipnft_id": ',
            tokenId,
            ',"agreement_content": "ipfs://',
            _metadata.agreementCid,
            '","original_owner": "',
            Strings.toHexString(_metadata.originalOwner),
            '","erc20_contract": "',
            Strings.toHexString(address(wrappedToken)),
            '","supply": "',
            Strings.toString(wrappedToken.totalSupply()),
            '"}'
        );

        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "IP Tokens of IPNFT #',
                        tokenId,
                        '","description": "IP Tokens, derived from IP-NFTs, are ERC-20 tokens governing IP pools.","decimals": ',
                        Strings.toString(wrappedToken.decimals()),
                        ',"external_url": "https://molecule.xyz","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}
