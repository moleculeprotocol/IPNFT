# IPNFT subgraph

## Prerequisites

-   you can deploy contracts locally (see the main folder)
-   you'll need docker (and docker-compose) on your box
-   install jq (`apt i jq` / `brew install jq`)

### Running subgraph and contracts locally

1. follow the local anvil deployment instructions [in the main repo](../README.md) to create a local deployment by running the fixture or dev scripts.
2. Ensure the resulting contract addresses match the ones in your .env file and are available in your local environment (`source .env`). When executied on a fresh node with the default mnemonic, the addresses in `.env.example` are the deterministic contract addresses.
3. Startup docker containers

```sh
docker compose up
```

The containers must be able to access your host box to connect to your local (anvil) chain. On Mac it likely just works since it supports `host.docker.internal`. On Linux run `setup.sh` can find your host's local network address and replace it in the compose file. Also make sure that your local blockchain node responds to the interface's traffic (e.g. by `anvil -h 0.0.0.0`). If you can't get this to work, you can instead start a ganache node as a docker service by using the `docker-compose.ganache.yml` override file:

```sh
docker-compose --file docker-compose.yml --file docker-compose.ganache.yml up
```

4. Prepare subgraph deployment

```sh
yarn create-abis
yarn prepare:local
```

This copies over your contracts' ABIs and creates a `subgraph.yaml` file with the contract addresses on your local chain, according to your environment.

5. Build and deploy the subgraph

```sh
yarn build
yarn create-local
yarn deploy-local
```

5. Checkout the local GraphQL API at <http://localhost:8000/subgraphs/name/moleculeprotocol/ipnft-subgraph>

If your local dev node needs a little "push", this is how you manually can mine a block:

```sh
curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":1}' 127.0.0.1:8545
```

### deploying on the hosted service:

1. get an api key for using the hosted service
2. `yarn graph auth --product hosted-service <your api key>`
3. `yarn graph deploy --product hosted-service <userprefix>/<graphname>`

### manually interacting with the contracts

ensure your local environment contains all contract addresses and is sourced to your terminal. We're using your local PRIVATE_KEY here

0. Mint a mintpass to deployer

`cast send -i $MINTPASS_ADDRESS --private-key $PRIVATE_KEY --rpc-url $ANVIL_RPC_URL "safeMint(address)" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"`

1. Create a reservation

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY --rpc-url $ANVIL_RPC_URL "reserve()"`

2. update its reservationURI

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "updateReservationURI(uint256, string calldata)()" 0 "teststring"`

3. mint an IP-NFT to the first account

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "mintReservation(address, uint256)(uint256)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 0`

4. approve for SchmackoSwap Contract to spend token 0
   `cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "approve(address, uint256)()" $SOS_ADDRESS 0`

5. Create a Listing for 10 Sample tokens

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "list(address, uint256, address, uint256)(uint256)" $IPNFT_ADDRESS 0 $ERC20_ADDRESS 10`

take note of the resulting listing id

6. Cancel a listing

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "cancel(uint256)()" <listingid>`

### Demo allowlisting and fulfilling

7. Create a new Listing (take down id)

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "list(address, uint256, address, uint256)(uint256)" $IPNFT_ADDRESS 0 $ERC20_ADDRESS 10`

8. allow Account(1)

`cast send -i $SOS_ADDRESS "changeBuyerAllowance(uint256, address, bool)()" <listingid> 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 true`

9. supply Account(1) with ERC20

`cast send -i $ERC20_ADDRESS --private-key $PRIVATE_KEY "mint(address, uint256)()" 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 10`

10. allow SOS to spend ERC20

`cast send --i $ERC20_ADDRESS --private-key <account1 private key> "increaseAllowance(address, uint256)()" $SOS_ADDRESS 10`

11. let account(1) fulfill the listing

`cast send -i \$SOS_ADDRESS --private-key <account1 private key> "fulfill(uint256)()" <listingid>`

### Calling view functions on the contract

`cast call $IPNFT_ADDRESS "tokenURI(uint256)" 1 | cast --to-ascii`
