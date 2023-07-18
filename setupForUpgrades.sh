#!/usr/bin/env bash

# use deterministic addresses
#source ./.env.upgrades
set -a
  . ./.env.upgrades
set +a


# Deployments
forge script script/dev/Ipnft.s.sol:DeployIpnftSuite -f $RPC_URL --broadcast
forge script script/dev/Tokens.s.sol:DeployTokens -f $RPC_URL --broadcast 
#forge script script/dev/Periphery.s.sol -f $RPC_URL --broadcast
forge script script/dev/Synthesizer.s.sol:DeploySynthesizer -f $RPC_URL --broadcast 
forge script script/dev/CrowdSale.s.sol:DeployCrowdSale -f $RPC_URL --broadcast
forge script script/dev/Tokens.s.sol:DeployFakeTokens -f $RPC_URL --broadcast 

forge script script/dev/Ipnft.s.sol:FixtureIpnft -f $RPC_URL --broadcast
forge script script/dev/Synthesizer.s.sol:FixtureSynthesizer -f $RPC_URL --broadcast
forge script script/dev/CrowdSale.s.sol:FixtureCrowdSale -f $RPC_URL --broadcast

sleep 5
echo "SALE_ID= forge script script/dev/CrowdSale.s.sol:ClaimSale -f $RPC_URL --broadcast" 
echo "forge script script/dev/CrowdSale.s.sol:ClaimSale -f $RPC_URL --broadcast" 
