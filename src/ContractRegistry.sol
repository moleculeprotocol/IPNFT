// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Contract Registry
 * @author stefan@molecule.to
 * @notice used for simpler contract configuration. Can yield standard contract addresses & resolve token contract addresses
 * @notice convention for multipart keys is to `keccak256(abi.encodePacked("key.",address))`
 */
contract ContractRegistry is Ownable {
    mapping(bytes32 => address) registry;

    constructor() Ownable() { }

    function register(bytes32 name, address _contract) public onlyOwner {
        registry[name] = _contract;
    }

    function get(bytes32 name) public view returns (address) {
        return registry[name];
    }

    function safeGet(bytes32 name) public view returns (address) {
        address _address = get(name);
        if (_address == address(0)) {
            revert("unresolvable");
        }
        return _address;
    }
}

//preconfigured registries, it *might* be safer to configure this manually!
// token list as reference: https://static.optimism.io/optimism.tokenlist.json

// https://community.optimism.io/docs/useful-tools/networks/#optimism-mainnet
// https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/mainnet#layer-1-contracts
// on mainnet we could also query common contracts by their name from here: https://etherscan.io/address/0xdE1FCfB0851916CA5101820A69b13a4E276bd81F#code
contract ContractRegistryMainnet is ContractRegistry {
    constructor() ContractRegistry() {
        //https://community.optimism.io/docs/useful-tools/networks/#optimism-mainnet
        registry["CrossdomainMessenger"] = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
        //https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/deployments/mainnet/Proxy__OVM_L1StandardBridge.json
        //todo WARNING: this imo is *not* bedrock compatible
        //todo: test this first before allowing any real user to use it!
        registry["StandardBridge"] = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;

        //USDC uses the standard bridge
        //https://etherscan.io/tx/0x3294b2578762bd3f32d17897ab79b02d4ec77dc3438c0692517bc3cb934adab7
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)))] =
            0x10E6593CDda8c58a1d0f14C5164B376352a55f2F;
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)))] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;

        //DAI on mainnet dai uses its own token bridge, 0x10E6593CDda8c58a1d0f14C5164B376352a55f2F
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0x6B175474E89094C44Da98b954EedeAC495271d0F)))] =
            0x10E6593CDda8c58a1d0f14C5164B376352a55f2F;
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0x6B175474E89094C44Da98b954EedeAC495271d0F)))] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

        //Tether USDT uses standard bridge on mainnet
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0xdAC17F958D2ee523a2206206994597C13D831ec7)))] =
            0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0xdAC17F958D2ee523a2206206994597C13D831ec7)))] = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    }
}

// * görli (bedrock): https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts-bedrock/deployments/goerli

contract ContractRegistryGoerli is ContractRegistry {
    constructor() ContractRegistry() {
        //https://community.optimism.io/docs/useful-tools/networks/#optimism-goerli
        registry["CrossdomainMessenger"] = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

        // here it's explicitly mentioned that the Porxy__OVM contracts are out of date:
        // https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/goerli#network-info
        // instead, the newer bedrock stack is used: https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts-bedrock
        // -> https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/deployments/goerli/L1StandardBridge.json at 0x2Fd98C3581b658643C18CCea9b9181ba3a7F7c54
        //but proxied by L1ChugSplashProxy:
        //https://goerli.etherscan.io/address/0x636af16bf2f682dd3109e60102b8e1a089fedaa8#code
        registry["StandardBridge"] = 0x636Af16bf2f682dD3109e60102b8E1A089FedAa8;

        //OUTb on Görli
        //uses standard bridge
        //https://goerli-optimism.etherscan.io/token/0x3e7ef8f50246f725885102e8238cbba33f276747
        //https://github.com/ethereum-optimism/optimism-tutorial/tree/main/cross-dom-bridge-erc20
        //https://community.optimism.io/docs/guides/testing/#

        //0x8237a1a7bac8d4da9b0ba16696cf5eae25ef4bbaad331664cbbc3b29cef450bb
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0x32B3b2281717dA83463414af4E8CfB1970E56287)))] =
            0x636Af16bf2f682dD3109e60102b8E1A089FedAa8;

        //0x3d1ff8fe761923407871aa7533d23fd79ac04beabcc94c6380d7d50891dbc809
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0x32B3b2281717dA83463414af4E8CfB1970E56287)))] = 0x3e7eF8f50246f725885102E8238CBba33F276747;

        //USDC on Görli
        //0xd16bd7eca49da7b1846b3691b7e922f4f5781147c87220e515bb291ccaa7572b
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0x07865c6E87B9F70255377e024ace6630C1Eaa37F)))] =
            0x636Af16bf2f682dD3109e60102b8E1A089FedAa8;
        //0x5cd4cfe0c62685b232d3156f3223d7a1d21bf042a16fded465c8c7b76aaeab06
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0x07865c6E87B9F70255377e024ace6630C1Eaa37F)))] = 0x7E07E15D2a87A24492740D16f5bdF58c16db0c4E;

        //DAI on Görli
        //0xe15b5f385938941efb63398e068187f4ba88d6aff64d6c7f544d27cdfbca5a44
        registry[bytes32(keccak256(abi.encodePacked("bridge.", 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844)))] =
            0x05a388Db09C2D44ec0b00Ee188cD42365c42Df23;

        //0x4a7108bf7a9b3c6f140d376e92e6c9e5a1d137cf084270648a50ecf66716c815
        registry[bytes32(keccak256(abi.encodePacked("l2.", 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844)))] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    }
}
