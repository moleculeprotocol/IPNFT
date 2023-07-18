#!/usr/bin/env bash

# use deterministic addresses
#source ./.env.upgrades
set -a
  . ./.env.upgrades
set +a

FSC="forge script -f $RPC_URL --broadcast --revert-strings debug"

# Deployments
$FSC script/dev/Ipnft.s.sol:DeployIpnftSuite 
$FSC script/dev/Tokens.s.sol:DeployTokens 
$FSC script/dev/Synthesizer.s.sol:DeploySynthesizer 
$FSC script/dev/CrowdSale.s.sol:DeployCrowdSale
$FSC script/dev/Tokens.s.sol:DeployFakeTokens  

$FSC script/dev/Ipnft.s.sol:FixtureIpnft 
$FSC script/dev/Synthesizer.s.sol:FixtureSynthesizer 
$FSC script/dev/CrowdSale.s.sol:FixtureCrowdSale 

sleep 16
cast rpc evm_mine

$FSC script/dev/CrowdSale.s.sol:ClaimSale
$FSC script/dev/Synthesizer.s.sol:UpgradeSynthesizerToTokenizer

