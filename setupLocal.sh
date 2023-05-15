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


# Main logic
if [ "$fixture" -eq "1" ]; then
  echo "Deploying contracts and running fixture scripts."

    forge script script/dev/Ipnft.s.sol:DeployIpnft -f $RPC_URL --broadcast
    forge script script/dev/Ipnft.s.sol:FixtureIpnft -f $RPC_URL --broadcast

    forge script script/dev/Fractionalize.s.sol:DeployFractionalizer -f $RPC_URL --broadcast
    forge script script/dev/Fractionalize.s.sol:FixtureFractionalizer -f $RPC_URL --broadcast

    forge script script/dev/CrowdSale.s.sol:DeployCrowdSale -f $RPC_URL --broadcast
    forge script script/dev/CrowdSale.s.sol:FixtureCrowdSale -f $RPC_URL --broadcast

else
  echo "Only deploying contracts."
    forge script script/dev/Ipnft.s.sol:DeployIpnft -f $RPC_URL --broadcast

    forge script script/dev/Fractionalize.s.sol:DeployFractionalizer -f $RPC_URL --broadcast

    forge script script/dev/CrowdSale.s.sol:DeployCrowdSale -f $RPC_URL --broadcast

fi
