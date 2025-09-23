// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/// @title IP Token Metadata Structure
/// @notice Metadata associated with an IP Token, linking it to its originating IPNFT
struct Metadata {
    /// @notice The ID of the IPNFT that this IP token is derived from
    uint256 ipnftId;
    /// @notice The original owner of the IPNFT at the time of token creation
    address originalOwner;
    /// @notice IPFS CID of the agreement governing this IP token
    string agreementCid;
}

/// @title IP Token Interface
/// @notice Interface for IP tokens that represent fractionalized intellectual property rights
/// @dev IP tokens are created from IPNFTs and represent transferable shares of IP ownership
interface IIPToken {
    /// @notice Returns the total amount of tokens that have ever been issued
    /// @dev This may differ from current supply due to potential burning mechanisms
    /// @return The total number of tokens issued since contract deployment
    function totalIssued() external view returns (uint256);

    /// @notice Returns the metadata associated with this IP token
    /// @return The metadata struct containing IPNFT ID, original owner, and agreement CID
    function metadata() external view returns (Metadata memory);

    /// @notice Issues new tokens to a specified address
    /// @param to The address to receive the newly issued tokens
    /// @param amount The number of tokens to issue
    function issue(address to, uint256 amount) external;

    /// @notice Returns or sets the maximum supply cap for this token
    /// @dev Implementation may vary - could be a getter or setter depending on context
    function cap() external;

    /// @notice Returns the URI for token metadata (typically IPFS)
    /// @return The URI string pointing to token metadata
    function uri() external view returns (string memory);
}
