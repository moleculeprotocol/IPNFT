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
./setupLocal.sh -f

cd subgraph
yarn prepare:local
yarn codegen
yarn create:local
yarn deploy:local -l v0.0.1

$DC exec -T postgres pg_dump -Fc -U graph-node -w graph-node -f after_setup.dump
cast rpc evm_snapshot

 