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
cat ../out/LockingCrowdSale.sol/LockingCrowdSale.json | jq .abi > ./abis/LockingCrowdSale.json
cat ../out/CrowdSale.sol/CrowdSale.json | jq .abi > ./abis/CrowdSale.json

cat ../out/Tokenizer.sol/Tokenizer.json | jq .abi > ./abis/_Tokenizer.json

# add the old Synthesizer's `MoleculesCreated` and `TokensCreated` event to the Tokenizer abi so the subgraph can index them
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

# add the old StakedLockingCrowdSale's `Started` event to the abi so the subgraph can index them
#event Started(uint256 indexed saleId, address indexed issuer, Sale sale);

cat ../out/StakedLockingCrowdSale.sol/StakedLockingCrowdSale.json | jq .abi > ./abis/_StakedLockingCrowdSale.json
jq '. +=  [{
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "saleId",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "issuer",
        "type": "address"
      },
      {
        "components": [
          {
            "internalType": "contract IERC20Metadata",
            "name": "auctionToken",
            "type": "address"
          },
          {
            "internalType": "contract IERC20Metadata",
            "name": "biddingToken",
            "type": "address"
          },
          {
            "internalType": "address",
            "name": "beneficiary",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "fundingGoal",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "salesAmount",
            "type": "uint256"
          },
          {
            "internalType": "uint64",
            "name": "closingTime",
            "type": "uint64"
          },
          {
            "internalType": "contract IPermissioner",
            "name": "permissioner",
            "type": "address"
          }
        ],
        "indexed": false,
        "internalType": "struct Sale",
        "name": "sale",
        "type": "tuple"
      },
      {
        "components": [
          {
            "internalType": "contract IERC20Metadata",
            "name": "stakedToken",
            "type": "address"
          },
          {
            "internalType": "contract TokenVesting",
            "name": "stakesVestingContract",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "wadFixedStakedPerBidPrice",
            "type": "uint256"
          }
        ],
        "indexed": false,
        "internalType": "struct StakingInfo",
        "name": "staking",
        "type": "tuple"
      },
      {
        "indexed": false,
        "internalType": "contract TimelockedToken",
        "name": "lockingToken",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "lockingDuration",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "stakingDuration",
        "type": "uint256"
      }
    ],
    "name": "Started",
    "type": "event"
  }]' ./abis/_StakedLockingCrowdSale.json > ./abis/StakedLockingCrowdSale.json
  rm ./abis/_StakedLockingCrowdSale.json