// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract DeployTestTokensManually is Script {
    function run() public {
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        uint256 supply = vm.envUint("SUPPLY_ETH");

        vm.startBroadcast();
        FakeERC20 token = new FakeERC20(name, symbol);
        token.mint(msg.sender, supply * 10 ** 18);
        vm.stopBroadcast();

        console.log("_TOKEN_ADDRESS=%s", address(token));
    }
}

contract DeployTokenVesting is Script {
    function run() public {
        vm.startBroadcast();
        IERC20Metadata underlyingToken = IERC20Metadata(vm.envAddress("TOKEN"));

        string memory symbol = string(abi.encodePacked("v", underlyingToken.symbol()));
        string memory name = string(abi.encodePacked("Vested ", underlyingToken.name()));

        TokenVesting vestedToken = new TokenVesting(underlyingToken, name, symbol);
        vm.stopBroadcast();

        console.log("V_TOKEN_ADDRESS=%s", address(vestedToken));
    }
}
