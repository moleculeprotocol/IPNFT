#!/usr/bin/env bash

cat ../out/IERC20Metadata.sol/IERC20Metadata.json | jq .abi > abis/IERC20Metadata.json
cat ../out/IPNFT.sol/IPNFT.json | jq .abi > ./abis/IPNFT.json
cat ../out/Mintpass.sol/Mintpass.json | jq .abi > ./abis/Mintpass.json
cat ../out/SchmackoSwap.sol/SchmackoSwap.json | jq .abi > ./abis/SchmackoSwap.json
cat ../out/IPToken.sol/IPToken.json | jq .abi > ./abis/IPToken.json
cat ../out/TimelockedToken.sol/TimelockedToken.json | jq .abi > ./abis/TimelockedToken.json
cat ../out/SalesShareDistributor.sol/SalesShareDistributor.json | jq .abi > ./abis/SharedSalesDistributor.json
cat ../out/Permissioner.sol/TermsAcceptedPermissioner.json | jq .abi > ./abis/TermsAcceptedPermissioner.json
cat ../out/StakedLockingCrowdSale.sol/StakedLockingCrowdSale.json | jq .abi > ./abis/StakedLockingCrowdSale.json
cat ../out/CrowdSale.sol/CrowdSale.json | jq .abi > ./abis/CrowdSale.json

cat ../out/Tokenizer.sol/Tokenizer.json | jq .abi > ./abis/_Tokenizer.json

# add the old Synthesizer's `MoleculesCreated` event to the Tokenizer abi so the subgraph can index them
jq '. +=  [{
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "moleculesId",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "ipnftId",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "tokenContract",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "address",
        "name": "emitter",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "agreementCid",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "symbol",
        "type": "string"
      }
    ],
    "name": "MoleculesCreated",
    "type": "event"
  }]' ./abis/_Tokenizer.json > ./abis/Tokenizer.json

  rm ./abis/_Tokenizer.json

