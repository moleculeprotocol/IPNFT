#!/usr/bin/env bash

# use deterministic addresses
#source ./.env.example
set -a
  . ./.env.example
set +a

fixtures=false
extrafixtures=false

show_help() {
    echo "Usage: setupLocal.sh [OPTION]"
    echo "Sets up the local environment for the IPNFT contracts."
    echo "Options:"
    echo "  -f  also runs basic fixture scripts"
    echo "  -x  also runs extra fixture scripts (crowdsales)"
}

# Parse command-line options
while getopts "fx" opt; do
  case ${opt} in
    f)
      fixtures=true
      ;;
    x)
      extrafixtures=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

FSC="forge script --chain 31337 --rpc-url $RPC_URL --use 0.8.18 --offline --broadcast --revert-strings debug"

# Deployments
$FSC script/dev/Ipnft.s.sol:DeployIpnftSuite 
$FSC script/dev/Tokens.s.sol:DeployTokens  
$FSC script/dev/Periphery.s.sol 
$FSC script/dev/Tokenizer.s.sol:DeployTokenizer  
$FSC script/dev/CrowdSale.s.sol:DeployStakedCrowdSale 
$FSC script/dev/Tokens.s.sol:DeployFakeTokens
$FSC script/dev/CrowdSale.s.sol:DeployCrowdSale 

# optionally: fixtures
if $fixtures; then
  echo "Running fixture scripts."

  $FSC script/dev/Ipnft.s.sol:FixtureIpnft 
  $FSC script/dev/Tokenizer.s.sol:FixtureTokenizer
fi

# optionally: extra fixtures
if $extrafixtures; then
  echo "Running extra fixture scripts (crowdsales)."

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
