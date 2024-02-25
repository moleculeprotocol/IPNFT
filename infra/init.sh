#!/usr/bin/env bash
set -a
  . ./packages/contracts/.env.example
set +a

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

cd packages/contracts
./setupLocal.sh -f

cd ../../packages/subgraph
pnpm run codegen
pnpm run build:local
# a local subgraph deployment always considers itself "mainnet"
sed -ire  's/network\: foundry/network\: mainnet/g' subgraph.yaml
pnpm run create:local
pnpm run deploy:local -l v0.0.1

# not used atm
#$DC exec -T postgres pg_dump -Fc -U graph-node -w graph-node -f after_setup.dump
#cast rpc evm_snapshot
#echo "0x0" > ./deploy/SNAPSHOT