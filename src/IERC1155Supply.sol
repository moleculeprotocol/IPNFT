// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IERC1155Supply is IERC1155 {
    function totalSupply(uint256 id) external view returns (uint256);
    function exists(uint256 id) external view returns (bool);
}
