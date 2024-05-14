#!/usr/bin/env bash

# use deterministic addresses
#source ./.env.example
set -a
  . ./.env.example
set +a

fixture=0

# Parse command-line options
while [ "$#" -gt 0 ]; do
  case $1 in
    -f|--fixture)
      fixture=1
    ;;
    *)
      echo "Unknown option: $1"
      exit 1
    ;;
  esac
  shift
done

FSC="forge script  -f $RPC_URL --broadcast"

# Deployments
$FSC script/dev/Ipnft.s.sol:DeployIpnftSuite 
$FSC script/dev/Tokens.s.sol:DeployTokens  
$FSC script/dev/Periphery.s.sol 
$FSC script/dev/Tokenizer.s.sol:DeployTokenizer  
$FSC script/dev/CrowdSale.s.sol:DeployStakedCrowdSale 
$FSC script/dev/Tokens.s.sol:DeployFakeTokens
$FSC script/dev/CrowdSale.s.sol:DeployCrowdSale 

# optionally: fixtures
if [ "$fixture" -eq "1" ]; then
  echo "Running fixture scripts."

  $FSC script/dev/Ipnft.s.sol:FixtureIpnft 
  $FSC script/dev/Tokenizer.s.sol:FixtureTokenizer 

  $FSC script/dev/CrowdSale.s.sol:FixtureCrowdSale 
  echo "Waiting 15 seconds until claiming plain sale..."
  sleep 16
  cast rpc evm_mine
  CROWDSALE=$PLAIN_CROWDSALE_ADDRESS $FSC script/dev/CrowdSale.s.sol:ClaimSale

  $FSC script/dev/CrowdSale.s.sol:FixtureStakedCrowdSale
  echo "Waiting 15 seconds until claiming staked sale..."
  sleep 16
  cast rpc evm_mine
  CROWDSALE=$STAKED_LOCKING_CROWDSALE_ADDRESS $FSC script/dev/CrowdSale.s.sol:ClaimSale
fi
