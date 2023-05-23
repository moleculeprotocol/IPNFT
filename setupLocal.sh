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


# Deployments
forge script script/dev/Ipnft.s.sol:DeployIpnftSuite -f $RPC_URL --broadcast
forge script script/dev/Tokens.s.sol:DeployTokens -f $RPC_URL --broadcast 
forge script script/dev/Periphery.s.sol -f $RPC_URL --broadcast
forge script script/dev/Fractionalizer.s.sol:DeployFractionalizer -f $RPC_URL --broadcast 
forge script script/dev/CrowdSale.s.sol:DeployCrowdSale -f $RPC_URL --broadcast

# optionally: fixtures
if [ "$fixture" -eq "1" ]; then
  echo "Running fixture scripts."

    forge script script/dev/Ipnft.s.sol:FixtureIpnft -f $RPC_URL --broadcast
    forge script script/dev/Fractionalizer.s.sol:FixtureFractionalizer -f $RPC_URL --broadcast
    forge script script/dev/CrowdSale.s.sol:FixtureCrowdSale -f $RPC_URL --broadcast
    sleep 5
    echo "SALE_ID= forge script script/dev/CrowdSale.s.sol:ClaimSale -f $RPC_URL --broadcast" 
fi
