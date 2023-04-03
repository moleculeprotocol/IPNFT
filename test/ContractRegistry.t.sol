// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { ContractRegistry, ContractRegistryGoerli } from "../src/ContractRegistry.sol";

contract ContractRegistryTest is Test {
    address deployer = makeAddr("chucknorris");

    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    ContractRegistry registry;

    function setUp() public {
        vm.startPrank(deployer);

        registry = new ContractRegistry();

        vm.stopPrank();
    }

    function testFractionId() public {
        address sender = 0xe127A39da6eA2D7b1979372aE973a20baB08A80A;
        address collection = 0x36444254795ce6E748cf0317EEE4c4271325D92A;
        uint256 tokenId = 10;
        bytes32 hash = keccak256(abi.encodePacked(sender, collection, tokenId));
        console.logBytes32(hash);
    }

    function testSimpleSetAndGet() public {
        vm.startPrank(deployer);
        registry.register("CrossdomainMessenger", bob);
        vm.stopPrank();
        assertEq(registry.safeGet("CrossdomainMessenger"), bob);
    }

    function testPrebuiltBytes() public {
        bytes32 FractionalizerL2 = 0x4672616374696f6e616c697a65724c3200000000000000000000000000000000;
        vm.startPrank(deployer);
        registry.register(FractionalizerL2, bob);
        vm.stopPrank();
        assertEq(registry.safeGet("FractionalizerL2"), bob);
    }

    function testPrecompiledRegistries() public {
        vm.startPrank(deployer);
        registry = new ContractRegistryGoerli();
        vm.stopPrank();
        assertEq(registry.safeGet("CrossdomainMessenger"), 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294);
    }
}
