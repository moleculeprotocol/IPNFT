// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

bytes32 constant ROLE_CREATE_SCHEDULE = keccak256("ROLE_CREATE_SCHEDULE");   

/**
 * find Molecule's official Biodao token vesting contract here: 
 * https://github.com/moleculeprotocol/token-vesting-contract/blob/ba2f125f4fad2cd385ba9195bd9a777ce648ea03/contracts/TokenVesting.sol
 */
interface ITokenVesting is IAccessControl {
  function nativeToken() external returns (IERC20);
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revokable,
        uint256 _amount
    ) external;
}