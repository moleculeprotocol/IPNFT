// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { CommonScript } from "./Common.sol";

contract DeployTokens is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        FakeERC20 usdc = new FakeERC20("USDC Token", "USDC");

        FakeERC20 daoToken = new FakeERC20("BIO DAO Token", "BIO");
        TokenVesting vestedDaoToken = new TokenVesting(IERC20Metadata(address(daoToken)), "Vested BIODAO Token", "VBIO");
        vm.stopBroadcast();

        console.log("USDC_ADDRESS=%s", address(usdc));
        console.log("DAO_TOKEN_ADDRESS=%s", address(daoToken));
        console.log("VDAO_TOKEN_ADDRESS=%s", address(vestedDaoToken));
    }
}

contract DeployFakeTokens is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        FakeERC20 usdc6 = new FakeERC20("USDC Token 6", "USDC6");
        usdc6.setDecimals(6);
        usdc6.mint(alice, 1_000_000e6);
        usdc6.mint(charlie, 100_000e6);

        FakeERC20 weth = new FakeERC20("wrapped Fakethereum", "WFETH");
        weth.setDecimals(18);
        weth.mint(alice, 100 ether);
        weth.mint(charlie, 100 ether);
        vm.stopBroadcast();

        console.log("USDC6_ADDRESS=%s", address(usdc6));
        console.log("WETH_ADDRESS=%s", address(weth));
    }
}
