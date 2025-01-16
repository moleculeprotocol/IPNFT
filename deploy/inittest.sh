#!/usr/bin/env bash

if command -v docker-compose &> /dev/null
then
  DC="docker-compose"
else
  DC="docker compose"  
fi

$DC down --remove-orphans
sleep 5
$DC up -d
$DC ps 

./setupLocal.sh -fx

cd subgraph
yarn codegen
yarn build:local
yarn create:local
# that's a bad local config hack still required: the root's subgraph.yaml's network must be "mainnet" for foundry
sed -i '' -e 's/network\: foundry/network\: mainnet/g' build/subgraph.yaml
sed -i '' -e 's/network\: foundry/network\: mainnet/g' subgraph.yaml
yarn deploy:local -l v0.0.1
sed -i '' -e 's/network\: mainnet/network\: foundry/g' subgraph.yaml
cd ..

$DC exec -T postgres pg_dump -Fc -U graph-node -w graph-node -f after_setup.dump
cast rpc evm_snapshot
echo "0x0" > ./deploy/SNAPSHOT

 