# IPNFT subgraph

## Sepolia

API: https://subgraph.satsuma-prod.com/techs-team--4017766/moleculexyz-ipnft-sepolia/version/v0.0.1/api
Playground: https://subgraph.satsuma-prod.com/techs-team--4017766/moleculexyz-ipnft-sepolia/playground

## Mainnet

API: https://api.thegraph.com/subgraphs/name/moleculeprotocol/ip-nft-mainnet
Playground: https://api.thegraph.com/subgraphs/name/moleculeprotocol/ip-nft-mainnet/graphql

## Prerequisites

- you can deploy contracts locally (see [the main README](../README.md))
- you'll need docker (and docker-compose) on your box
- install jq (`apt i jq` / `brew install jq`)

### Running subgraph and contracts locally

1. follow the [local development deployment instructions](../README.md) to create a local deployment by running the fixture or dev scripts.
2. Ensure the resulting contract addresses match the ones in your .env file and are available in your local environment (`source .env`). When executed on a fresh node with the default mnemonic, the addresses in `.env.example` are the deterministic contract addresses.
3. Startup docker containers

```sh
docker compose up
```

The containers must be able to access your host box to connect to your local (anvil) chain. On Mac it likely just works since it can resolve `host.docker.internal`. On Linux `setup.sh` might be able to find your host's local network address and replace it in the compose file. Also make sure that you start your local blockchain node to be able to respond to the interface's traffic (e.g. by `anvil -h 0.0.0.0`). If you can't get this to work, you can instead start a ganache node as a docker service by using the `docker-compose.ganache.yml` override file:

```sh
docker-compose --file docker-compose.yml --file docker-compose.ganache.yml up
```

4. Prepare subgraph deployment

```sh
yarn abis
yarn prepare:local
```

This copies over your contracts' ABIs and creates a `subgraph.yaml` file with the contract addresses on your local chain, according to your environment.

5. Build and deploy the subgraph

```sh
yarn build
yarn create:local
yarn deploy:local
```

5. Checkout the local GraphQL API at <http://localhost:8000/subgraphs/name/moleculeprotocol/ipnft-subgraph>

If your local dev node needs a little "push", this is how you manually can mine a block:

```sh
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":1}' 127.0.0.1:8545
```

### deploying on the hosted service

1. get an api key for using the hosted service
2. `yarn graph auth --product hosted-service <your api key>`
3. `yarn graph deploy --product hosted-service <userprefix>/<graphname>`
