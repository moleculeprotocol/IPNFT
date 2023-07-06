#!/usr/bin/env bash

if command -v docker-compose &> /dev/null
then
  DC="docker-compose"
else
  DC="docker compose"  
fi

$DC down --remove-orphans
$DC up -d
./setupLocal.sh -f

cd subgraph
yarn prepare:local
yarn codegen
yarn create:local
yarn deploy:local -l v0.0.1
$DC ps 

cd ..
./deploy/snapzero.sh

 