// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("Sample ERC20 Token", "MTK") {}

    //anyone can print money.
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
