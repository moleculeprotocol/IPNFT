# BioFair - Molecule Crowdsales

## Prerequisites

To work with this repository you have to install Foundry (<https://getfoundry.sh>). Run the following command in your terminal, then follow the onscreen instructions (macOS and Linux):

`curl -L https://foundry.paradigm.xyz | bash`

The above command will install `foundryup`. Then install Foundry by running `foundryup` in your terminal.

(Check out the Foundry book for a Windows installation guide: <https://book.getfoundry.sh>)

## Usage

### install dependencies and build

Run `forge install`. This will clone dependency repos as submodules into the `lib` folder.

Run `forge build`

### Testing

Run `forge test`

Run `forge test --gas-report` for gas usage reports

Run `forge test --match-contract IPNFTV2 -vvv -w` to watch only relevant tests an include meaningful output


## Deployment

### General config

- The deploy scripts are located in `script`
- Copy `.env.example` to `.env`
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.
- Set a moderator address that's going to be enabled to issue and revoke mintpasses (only needed for "real" deployments)

You can place required env vars in your `.env` file and run `source .env` to get them into your current terminal session or provide them when invoking the command.

### Deployment scripts

- a fresh, proxied IPNFT deployment can be created by `forge script script/IPNFT.sol`
- to rollout a new upgrade on a live network without calling the proxy's upgrade function, you can use `forge script script/UpgradeImplementation.s.sol:DeployImplementation` and invoke the upgrade function manually (e.g. from your multisig)
- for the "real" thing you'll need to add `-f` and `--private-key` and finally `--broadcast` params .

### Deploy for local development

#### Quickstart

- You can use the shell script `./setupLocal.sh` to deploy all contracts and add the optional `-f` or `--fixture` flag to also run the fixture scripts.

#### Manual

- the dev scripts are supposed to run on your _local_ environment and depend on contract addresses on your local environment. Use `source .env` to pull deterministic local contract addresses to your local session.

- Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC. You can also use the anvil node from docker, see the [accompanying README in the `subgraph` folder](./subgraph/README.md).
- Run `anvil -h 0.0.0.0` in a terminal window and keep it running

To just deploy all contracts using the default mnemonic's first account, run `forge script script/dev/Ipnft.s.sol:DeployIpnft -f $RPC_URL --broadcast`

To issue a mintpass, reserve and mint a test IPNFT for the 1st user, run `forge script script/dev/Ipnft.s.sol:FixtureIpnft -f $RPC_URL --broadcast`. This requires you to have executed Dev.s.sol before. This also creates a listing on Schmackoswap but doesn't accept it.

To deploy the Synthesizer, run `forge script script/dev/Synthesizer.s.sol:DeploySynthesizer -f $RPC_URL --broadcast`
To synthesize the test IPNFT, run `forge script script/dev/Synthesizer.s.sol:FixtureSynthesizer -f $RPC_URL --broadcast`

To deploy the StakedLockingCrowdSale contract, run `forge script script/dev/CrowdSale.s.sol:DeployCrowdSale -f $RPC_URL --broadcast`
To test a simple StakedLockingCrowdSale with Molecules, run `forge script script/dev/CrowdSale.s.sol:FixtureCrowdSale -f $RPC_URL --broadcast`

To approve and finalize the sales listing, run `forge script script/dev/ApproveAndBuy.s.sol -f $RPC_URL --broadcast`. See the inline comment on why this is a separate script.

### Deploy to a live network

> The easiest way to deploy contracts without exposing a local private key is the thirdweb. Here's how you initialize the process from the root folder: `npx thirdweb@latest deploy`

To manually broadcast a bundle of deploy transactions, you can use `Deploy.s.sol`. It deploys all three relevant contracts (IPNFT, Schmackoswap and Mintpass) and sets up a first moderator (defined by the `MODERATOR_ADDRESS` env var). Make sure that you're using the correct moderator address for the network you're deploying to.

1. Make sure you have the private key for your deployer account at hand and that it has ETH on the target network on it.
2. Run `forge script script/Deploy.s.sol:DeployScript -f $RPC_URL --interactives 1 --sender <deployer address> --broadcast -vvvv`
3. Paste the private key for the deployer account
4. to verify the contract during deployment, get an Etherscan API key and add `--verify --etherscan-api-key $ETHERSCAN_API_KEY` to the command.

### Deploying the Synthesizer suite

You can deploy the Synthesizer individually, but we created a deployment script that deploys all relevant contracts in the recommended order. These are

- BioPriceFeed
- TermsAcceptedPermissioner
- Synthesizer
- StakedLockingCrowdSale

You can deploy them all in one go (requires the current network's IPNFT address):

`IPNFT_ADDRESS=... forge script script/DeploySynthesizer.s.sol:DeploySynthesizerInfrastructure --private-key $PRIVATE_KEY --rpc-url $RPC_URL --broadcast`

The crowdsale computation model can be tried out here: <https://docs.google.com/spreadsheets/d/1vvGzs6n0nGqSBewJFKPsX4umMDCwNhKVqqhGELY543g/edit?usp=sharing>

Deploying and verifying a single contract without the help of any script
`forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain 5 --etherscan-api-key $ETHERSCAN_API_KEY --verify src/crowdsale/StakedLockingCrowdSale.sol:StakedLockingCrowdSale`

### Deploying (vested) test tokens

To test staked / vested token interactions, you need some test tokens. Here are 2 convenient script to get them running:

`NAME=Vita SYMBOL=VITA SUPPLY_ETH=10000000 forge script script/Tokens.s.sol:DeployTestTokensManually --private-key $PRIVATE_KEY --rpc-url $RPC_URL --broadcast`

and to create the vested tokens counterpart:

`TOKEN=0xaddress forge script script/Tokens.s.sol:DeployITokenVesting --private-key $PRIVATE_KEY --rpc-url $RPC_URL --broadcast`




## Creating coverage reports

requires the lcov suite installed on your machine

```
forge coverage --report lcov && genhtml lcov.info -o report --branch-coverage
```

## Actions

We are using Tenderly Web3Actions to trigger actions based on emitted Events from our deployed Contracts.

These are setup under the moleculeprotocol organization on Tenderly.
The QueryIds and API-KEY are stored in the Tenderly context and can be accessed via the Tenderly Frontend.
To update these actions you need the Tenderly login credentials.

- StakedLockingCrowdSale (Mainnet & Goerli): BidEvent => Triggers a POST request that executes Dune Queries to update the Dune Visualizations.

You can find out more about Web3Actions on Tenderly here: <https://docs.tenderly.co/web3-actions/intro-to-web3-actions>
How to init & deploy new Web3Actions: <https://docs.tenderly.co/web3-actions/tutorials-and-quickstarts/deploy-web3-action-via-cli>
