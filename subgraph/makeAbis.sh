#!/usr/bin/env bash

cat ../out/IERC20Metadata.sol/IERC20Metadata.json | jq .abi > abis/IERC20Metadata.json
cat ../out/IPNFT.sol/IPNFT.json | jq .abi > ./abis/IPNFT.json
cat ../out/Mintpass.sol/Mintpass.json | jq .abi > ./abis/Mintpass.json
cat ../out/SchmackoSwap.sol/SchmackoSwap.json | jq .abi > ./abis/SchmackoSwap.json
cat ../out/Fractionalizer.sol/Fractionalizer.json | jq .abi > ./abis/Fractionalizer.json
cat ../out/FractionalizedToken.sol/FractionalizedToken.json | jq .abi > ./abis/FractionalizedToken.json
cat ../out/TimelockedToken.sol/TimelockedToken.json | jq .abi > ./abis/TimelockedToken.json
cat ../out/SalesShareDistributor.sol/SalesShareDistributor.json | jq .abi > ./abis/SharedSalesDistributor.json
cat ../out/Permissioner.sol/TermsAcceptedPermissioner.json | jq .abi > ./abis/TermsAcceptedPermissioner.json
cat ../out/StakedLockingCrowdSale.sol/StakedLockingCrowdSale.json | jq .abi > ./abis/StakedLockingCrowdSale.json
