#!/usr/bin/env bash

cat ../out/IPNFT.sol/IPNFT.json | jq .abi > ./abis/IPNFT.json
cat ../out/Mintpass.sol/Mintpass.json | jq .abi > ./abis/Mintpass.json
cat ../out/SchmackoSwap.sol/SchmackoSwap.json | jq .abi > ./abis/SchmackoSwap.json
cat ../out/Fractionalizer.sol/Fractionalizer.json | jq .abi > ./abis/Fractionalizer.json
cat ../out/FractionalizedToken.sol/FractionalizedToken.json | jq .abi > ./abis/FractionalizedToken.json