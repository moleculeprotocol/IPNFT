// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title IControlIPTs 1.3
 * @author molecule.xyz
 * @notice must be implemented by contracts that should control IPTs
 */
interface IControlIPTs {
    function controllerOf(uint256 ipnftId) external view returns (address);
}
