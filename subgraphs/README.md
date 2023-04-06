# IPNFT subgraph

## Prerequisites

- you can deploy contracts locally (see [the main README](../README.md))
- you'll need docker (and docker-compose) on your box
- install jq (`apt i jq` / `brew install jq`)

### Running subgraph and contracts locally

1. follow the [local development deployment instructions](../README.md) to create a local deployment by running the fixture or dev scripts.
2. Ensure the resulting contract addresses match the ones in your .env file and are available in your local environment (`source .env`). When executed on a fresh node with the default mnemonic, the addresses in `.env.example` are the deterministic contract addresses.
3. Startup docker containers (TODO: Add docker container setup for layer2 subgraph) For sanity's sake it's recommended to run the chain in docker as well, but if you want to connect the subgraph with a local anvil node, read 4.

```sh
docker compose -f docker-compose.yml -f docker-compose.chain.yml up
```

4. If you're running a local blockchain, the docker containers must be able to access your host box to connect to it. On Mac it likely just works out of the box since it can resolve `host.docker.internal`. On Linux `setup.sh` might be able to find your host's local network address and replace it in the compose file. Also make sure that you start your local blockchain node to be able to respond to the interface's traffic (e.g. by `anvil -h 0.0.0.0`). If you can't get this to work, stick with step 3.

### Prepare subgraph deployment

First copy over all the relevant ABIs

```sh
yarn abis
```

and generate `subgraph.yml` configuration files for the desired target environment on both layers

```sh
yarn prepare:local
# or yarn prepare:goerli
# or yarn prepare:mainnet
```

You can execute `yarn codegen` to generate all TS definitions and schema entities but that's also done during the build step that builds the subgraph WASM binaries for both layers:

```sh
yarn build
```

Finally, create your local subgraph deployment on the subgraph nodes (this must only happen once while the containers run):

```sh
yarn create:local
```

and deploy the WASM binaries to the instance:

```sh
yarn deploy:local
```

The local GraphQL API should now be available at <http://localhost:8000/subgraphs/name/moleculeprotocol/ipnft-subgraph>

If your local dev node needs a little "push", this is how you manually can mine a block:

```sh
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":1}' 127.0.0.1:8545
```

### deploying on the hosted service

1. get an api key for using the hosted service
2. `yarn graph auth --product hosted-service <your api key>`
3. `yarn graph deploy --product hosted-service <userprefix>/<graphname>`
