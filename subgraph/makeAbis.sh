#!/usr/bin/env bash

cat ../out/IPNFT.sol/IPNFT.json | jq .abi > ./layer1/abis/IPNFT.json
cat ../out/Mintpass.sol/Mintpass.json | jq .abi > ./layer1/abis/Mintpass.json
cat ../out/SchmackoSwap.sol/SchmackoSwap.json | jq .abi > ./layer1/abis/SchmackoSwap.json
cat ../out/FractionalizerL2Dispatcher.sol/FractionalizerL2Dispatcher.json | jq .abi > ./layer1/abis/FractionalizerL2Dispatcher.json

cat ../out/Fractionalizer.sol/Fractionalizer.json | jq .abi > ./layer2/abis/Fractionalizer.json