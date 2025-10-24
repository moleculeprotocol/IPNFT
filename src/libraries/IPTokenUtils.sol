// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import { Metadata } from "../IIPToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title IP Token Utilities Library
/// @notice Shared utilities for IP Token contracts
/// @dev Contains common functions used by both IPToken and WrappedIPToken
library IPTokenUtils {
    /// @notice Generates a base64-encoded data URL containing token metadata
    /// @param metadata_ The metadata struct containing IPNFT information
    /// @param tokenContract The ERC20 token contract address
    /// @param supply The token supply to include in metadata
    /// @return The complete data URL string
    function generateURI(Metadata memory metadata_, address tokenContract, uint256 supply) internal view returns (string memory) {
        string memory tokenId = Strings.toString(metadata_.ipnftId);

        string memory props = string.concat(
            '"properties": {',
            '"ipnft_id": ',
            tokenId,
            ',"agreement_content": "ipfs://',
            metadata_.agreementCid,
            '","original_owner": "',
            Strings.toHexString(metadata_.originalOwner),
            '","erc20_contract": "',
            Strings.toHexString(tokenContract),
            '","supply": "',
            Strings.toString(supply),
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
                        Strings.toString(IERC20Metadata(tokenContract).decimals()),
                        ',"external_url": "https://molecule.xyz","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}
