#!/bin/bash
source .env

ANVIL_RPC_URL="${ANVIL_RPC_URL:=http://127.0.0.1:8545}" 

forge b
forge script script/dev/Dev.s.sol --rpc-url $ANVIL_RPC_URL --broadcast
forge script script/dev/Mint.s.sol --rpc-url $ANVIL_RPC_URL --broadcast
forge script script/dev/ApproveAndBuy.s.sol --rpc-url $ANVIL_RPC_URL 

cd subgraph
yarn prepare:local
yarn build
yarn create-local
yarn deploy-local
