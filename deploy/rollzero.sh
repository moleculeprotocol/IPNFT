#!/usr/bin/env bash

if command -v docker-compose &> /dev/null
then
  DC="docker-compose"
else
  DC="docker compose"  
fi

#todo check whether docker is operational & cast is available here.

$DC stop graph-node 
docker container wait ipnft_graph-node_1
cast rpc evm_revert $1

$DC exec postgres dropdb -U graph-node -w graph-node
$DC exec postgres createdb -U graph-node -w graph-node
$DC exec postgres pg_restore -U graph-node -w -d graph-node gn.dump

# alternatively 
# $DC exec postgres psql -U graph-node -d postgres -c 'ALTER DATABASE "graph-node" WITH ALLOW_CONNECTIONS false;'
# $DC exec postgres psql -U graph-node -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='graph-node'";
# $DC exec postgres psql -U graph-node -d postgres -c 'ALTER DATABASE "graph-node" WITH ALLOW_CONNECTIONS true;'
# $DC restart graph-node

$DC start graph-node
sleep 5
cast rpc evm_snapshot
