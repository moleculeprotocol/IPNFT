# IPNFT subgraph

## prerequisites

- contracts have to be built
- install jq (`apt i jq` / `brew install jq`)

## getting the latest contract abis

- `yarn create-ipnft-abi`
- `yarn create-schmackoSwap-abi` (needs SchmackoSwap outputs here)

### Running subgraph and contracts locally

you'll need docker / docker-compose on your box

follow the local anvil deployment instructions [in the main repo](../README.md)

Note all the contract addresses that the following commands are creating, and add them to your .env file. If you're executing them in exactly this order on a fresh anvil node with the default mnemonic, the addresses are "deterministic".

Since your local env is stil configured for your anvil node, it can be reused for the other deployments

1. Deploy local IP-NFT contract, SchmackoSwap and MyToken (ERC-20 contract)
   `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv`

2. add the deployed contract addresses to your .env file, `source .env` again. We've added their deterministic addresses when deployed in that order for convenienc.

3. Startup docker containers

```sh
docker compose up
```

The containers must be able to access your host box to connect to your local (anvil) chain. On Mac it likely just works since it supports `host.docker.internal`. On Linux run `setup.sh` to find your host's local network address and replace it in the compose file. Also make sure that your local blockchain node responds to the interface's traffic (e.g. by `anvil -h 0.0.0.0`)

4. Prepare subgraph for local build, create and deploy

This creates a `subgraph.yaml` file with the correct contract addresses of your local chain

```sh
yarn prepare:local
yarn build
yarn create-local
yarn deploy-local
```

5. Checkout the local GraphQL API at <http://localhost:8000/subgraphs/name/moleculeprotocol/ipnft-subgraph>

### manually interacting with the contracts

ensure your local environment contains all contract addresses and is sourced to your terminal. We're using your local PRIVATE_KEY here

1. Create a reservation

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "reserve()(uint256)"`

2. update its reservationURI

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "updateReservationURI(uint256, string calldata)()" 0 "teststring"`

3. mint an IP-NFT to the first account

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "mintReservation(address, uint256)(uint256)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 0`

4. approve for SchmackoSwap Contract to spend token 0
   `cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "approve(address, uint256)()" $SOS_ADDRESS 0`

5) Create a Listing for 10 Sample tokens

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
