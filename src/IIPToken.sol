// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

struct Metadata {
    uint256 ipnftId;
    address originalOwner;
    string agreementCid;
}

interface IIPToken {
    /// @notice the amount of tokens that ever have been issued (not necessarily == supply)
    function totalIssued() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function metadata() external view returns (Metadata memory);
    function issue(address, uint256) external;
    function cap() external;
    function uri() external view returns (string memory);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
