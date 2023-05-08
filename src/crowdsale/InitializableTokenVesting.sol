    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

//contract InitializeableTokenVesting is Initializable, TokenVesting {
contract InitializeableTokenVesting is TokenVesting {
    constructor(IERC20Metadata token_, string memory _name, string memory _symbol) TokenVesting(token_, _name, _symbol) { }
    // constructor() {
    //     _disableInitializers();

    //     //      TokenVesting(address(0), "", "");
    // }

    function initialize(IERC20Metadata token_) public {
        //initializer
        //nativeToken = token_;
        if (nativeToken.decimals() != 18) revert DecimalsError();
        name = string(abi.encodePacked("Vested ", token_.name()));
        symbol = string(abi.encodePacked("v", token_.symbol()));
    }
}
