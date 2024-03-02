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

FSC="forge script  -f $RPC_URL --broadcast --legacy --revert-strings debug"
DEPLOY_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Deployments
$FSC --private-key $DEPLOY_KEY script/CrowdSale.s.sol:DeployPeriphery 
$FSC --private-key $DEPLOY_KEY script/CrowdSale.s.sol:DeployCrowdSale 
$FSC --private-key $DEPLOY_KEY script/CrowdSale.s.sol:DeployStakedCrowdSale 

# optionally: fixtures
if [ "$fixture" -eq "1" ]; then
  echo "Running fixture scripts."

  $FSC script/dev/TestSetup.s.sol:DeployFakeTokens
  $FSC script/dev/TestSetup.s.sol:DeployPermissionedToken
  $FSC script/dev/TestSetup.s.sol:DeployTokenVesting
  $FSC script/dev/TestSetup.s.sol:FixtureCrowdSale 

  echo "Waiting 15 seconds until claiming plain sale..."
  sleep 15
  cast rpc --rpc-url $RPC_URL evm_mine
  CROWDSALE=$PLAIN_CROWDSALE_ADDRESS $FSC script/dev/TestSetup.s.sol:ClaimSale

  # $FSC script/dev/TestSetup.s.sol:FixtureStakedCrowdSale
  # echo "Waiting 15 seconds until claiming staked sale..."
  # sleep 15
  # cast rpc --rpc-url $RPC_URL evm_mine
  # CROWDSALE=$STAKED_LOCKING_CROWDSALE_ADDRESS $FSC script/dev/TestSetup.s.sol:ClaimSale
fi
