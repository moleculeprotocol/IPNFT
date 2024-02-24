#!/usr/bin/env bash

if command -v docker-compose &> /dev/null
then
  DC="docker-compose --ansi=never"
else
  DC="docker compose --progress=plain --ansi=never"  
fi

CURRENT_SNAPSHOT=$(<./deploy/SNAPSHOT)

#todo check whether docker is operational & cast is available here.

# if [[ "$OSTYPE" == "darwin"* ]]; then
#   GRAPH_CONTAINER=ipnft-graph-node-1
# else
#   GRAPH_CONTAINER=ipnft_graph-node_1
# fi

#GRAPH_CONTAINER="ipnft_graph-node_1"

# we can only *wait* for a *container name* but must address the container by its compose service name...
# earn a beer by making this work:
scname=`docker inspect -f '{{.Name}}' $(docker compose ps -q graph-node)`
GRAPH_CONTAINER=${scname:1}

$DC stop graph-node 
docker container wait $GRAPH_CONTAINER
cast rpc evm_revert $CURRENT_SNAPSHOT

$DC exec -T postgres dropdb -U graph-node -w graph-node
$DC exec -T postgres createdb -U graph-node -w graph-node
$DC exec -T postgres pg_restore -U graph-node -w -d graph-node after_setup.dump

# alternatively 
# $DC exec postgres psql -U graph-node -d postgres -c 'ALTER DATABASE "graph-node" WITH ALLOW_CONNECTIONS false;'
# $DC exec postgres psql -U graph-node -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='graph-node'";
# $DC exec postgres psql -U graph-node -d postgres -c 'ALTER DATABASE "graph-node" WITH ALLOW_CONNECTIONS true;'
# $DC restart graph-node

$DC start graph-node
#wait for graph-node to be alive again
curl --retry-connrefused --retry-all-errors --max-time 30 --retry 10 --retry-delay 3 --retry-max-time 60 http://127.0.0.1:8030

cast rpc evm_snapshot > ./deploy/SNAPSHOT

