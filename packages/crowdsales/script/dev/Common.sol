// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";

contract CommonScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    address deployer;
    address bob;
    address alice;
    address charlie;
    address anyone;

    uint256 deployerPk;
    uint256 alicePk;
    uint256 bobPk;
    uint256 charliePk;

    function prepareAddresses() internal virtual {
        (deployer, deployerPk) = deriveRememberKey(mnemonic, 0);
        (bob, bobPk) = deriveRememberKey(mnemonic, 1);
        (alice, alicePk) = deriveRememberKey(mnemonic, 2);
        (charlie, charliePk) = deriveRememberKey(mnemonic, 3);
        (anyone,) = deriveRememberKey(mnemonic, 4);
    }

    function dealERC20(address to, uint256 amount, FakeERC20 token) internal {
        vm.startBroadcast(deployer);
        token.mint(to, amount);
        vm.stopBroadcast();
    }
}
