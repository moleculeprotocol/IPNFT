// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Upgreat is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    constructor() {}

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
    }

    function speak() public pure returns (string memory) {
        return "great";
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal view override {
        //empty block
    }
}
