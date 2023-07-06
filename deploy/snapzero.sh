#!/usr/bin/env bash

if command -v docker-compose &> /dev/null
then
  DC="docker-compose"
else
  DC="docker compose"  
fi

#todo check whether docker is operational & cast is available here.

$DC exec postgres pg_dump -Fc -U graph-node -w graph-node -f gn.dump
cast rpc evm_snapshot

 