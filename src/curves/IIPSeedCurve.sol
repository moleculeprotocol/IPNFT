// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum TradeType {
    Buy,
    Sell
}

/**
 * @title IIPSeedCurve
 * @author tech@molecule.to
 * @notice the generic interface for a price bonding curve
 */
interface IIPSeedCurve {
    /**
     * @param supply the current curve's supply
     * @param want the amount to buy
     * @param curveParameters the encoded curve parameters
     */
    function getBuyPrice(uint256 supply, uint256 want, bytes32 curveParameters) external pure returns (uint256);

    /**
     * @dev reverts with an arithmetic error when sell > supply
     * @param supply the current curve's supply
     * @param sell the amount to sell on the curve
     * @param curveParameters the encoded curve parameters
     */
    function getSellPrice(uint256 supply, uint256 sell, bytes32 curveParameters) external pure returns (uint256);

    /// @notice inverse of getBuyPrice (eth -> tokens)
    function getTokensForValue(uint256 supply, uint256 amount, bytes32 curveParameters) external pure returns (uint256);

    function areParametersInRange(bytes32 curveParameters) external pure returns (bool);
}
