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

FSC="forge script  -f $RPC_URL --broadcast --revert-strings debug"

# Deployments
$FSC script/dev/Ipnft.s.sol:DeployIpnftSuite 
$FSC script/dev/Tokens.s.sol:DeployTokens  
$FSC script/dev/Periphery.s.sol 
$FSC script/dev/Tokenizer.s.sol:DeployTokenizer  
$FSC script/dev/CrowdSale.s.sol:DeployCrowdSale 
$FSC script/dev/Tokens.s.sol:DeployFakeTokens  

# optionally: fixtures
if [ "$fixture" -eq "1" ]; then
  echo "Running fixture scripts."

  $FSC script/dev/Ipnft.s.sol:FixtureIpnft 
  $FSC script/dev/Tokenizer.s.sol:FixtureTokenizer 
  $FSC script/dev/CrowdSale.s.sol:FixtureCrowdSale 
    
  echo "Waiting 15 seconds until claiming sale..."
  sleep 16
  cast rpc evm_mine

  $FSC script/dev/CrowdSale.s.sol:ClaimSale
fi
