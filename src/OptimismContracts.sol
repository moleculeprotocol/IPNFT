// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title
 * @author
 * @notice
 *
 * https://community.optimism.io/docs/useful-tools/networks/#optimism-mainnet
 * https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/mainnet#layer-1-contracts
 *
 * görli (bedrock): https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts-bedrock/deployments/goerli
 *
 * on mainnet we could also query common contracts by their name from here: https://etherscan.io/address/0xdE1FCfB0851916CA5101820A69b13a4E276bd81F#code
 */
library OptimismContracts {
    function getStandardBridgeAddress() public view returns (address) {
        // Mainnet
        //https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/deployments/mainnet/Proxy__OVM_L1StandardBridge.json
        //seems to be good (eof Feb 23): https://etherscan.io/txs?a=0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1
        //todo WARNING: this imo is *not* bedrock compatible
        if (block.chainid == 1) {
            return 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1;
        }

        // Goerli
        // here it's explicitly mentioned that the Porxy__OVM contracts are out of date:
        // https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts/deployments/goerli#network-info
        // instead, the newer bedrock stack is used: https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts-bedrock
        // -> https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts-bedrock/deployments/goerli/L1StandardBridge.json at 0x2Fd98C3581b658643C18CCea9b9181ba3a7F7c54
        //but proxied by L1ChugSplashProxy:
        //https://goerli.etherscan.io/address/0x636af16bf2f682dd3109e60102b8e1a089fedaa8#code

        if (block.chainid == 5) {
            return 0x636Af16bf2f682dD3109e60102b8E1A089FedAa8;
        }

        revert("bridge invalid");
    }

    //todo: only works for görli:
    function getCrossdomainMessengerAddress() public view returns (address) {
        if (block.chainid == 1) {
            return 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
        }
        if (block.chainid == 5) {
            return 0x636Af16bf2f682dD3109e60102b8E1A089FedAa8;
        }

        revert("no cross domain messenger");
    }

    function getTokenAddressL2(address tokenAddressL1) public view returns (address) {
        if (block.chainid == 1) {
            //USDC todo: likely to work
            //https://etherscan.io/tx/0x3294b2578762bd3f32d17897ab79b02d4ec77dc3438c0692517bc3cb934adab7
            if (tokenAddressL1 == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
                return 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; //USDC on Optimism
            }
            //DAI todo: careful!!! dai seems not compatible to the standard token bridge,
            // if (tokenAddressL1 == 0x6B175474E89094C44Da98b954EedeAC495271d0F) {
            //     return 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; //DAI on Optimism
            // }
        } else if (block.chainid == 5) {
            //https://community.optimism.io/docs/guides/testing/#
            //https://github.com/ethereum-optimism/optimism-tutorial/tree/main/cross-dom-bridge-erc20
            //OUTb
            if (tokenAddressL1 == 0x32B3b2281717dA83463414af4E8CfB1970E56287) {
                //OUTb on Görli
                //https://goerli-optimism.etherscan.io/token/0x3e7ef8f50246f725885102e8238cbba33f276747
                return 0x3e7eF8f50246f725885102E8238CBba33F276747; //OUTb on Optimism
            }

            //Görli Token Standard Bridge 0x636Af16bf2f682dD3109e60102b8E1A089FedAa8
        } else if (block.chainid == 31337) { }

        revert("no token known on l2");
    }
}