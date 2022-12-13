# IPNFT

Template for NFT contracts tokenizing IP.

## Deployments

### Goerli

- IP-NFT <https://goerli.etherscan.io/address/0x5fbdb2315678afecb367f032d93f642f64180aa3#code>
- SchmackoSwap <https://goerli.etherscan.io/address/0xe7f1725e7734ce288f8367e1bb143e90bb3f0512#code>
- The Graph: <https://thegraph.com/explorer/subgraph/dorianwilhelm/ip-nft-subgraph-goerli>

## Installation

To work with this repository you have to install Foundry (<https://getfoundry.sh>).

Run the following command in your terminal, then follow the onscreen instructions (macOS and Linux):

`curl -L https://foundry.paradigm.xyz | bash`

The above command will install `foundryup`. Then install Foundry by running `foundryup` in your terminal.

(Check out the Foundry book for a Windows installation guide: <https://book.getfoundry.sh>)

## Usage

### Run tests

Run `forge test`

### Run tests and get a gas usage report

Run `forge test --gas-report`

![CleanShot 2022-08-14 at 15 08 17](https://user-images.githubusercontent.com/86414213/184538476-20c8ff24-4714-44bf-a618-f6176cabd03c.png)

### Run dedicated tests and watch with meaningful output

`forge test --match-contract IPNFT3525 -vvv -w`

### Run hardhat tests

We added a basic hardhat environment to this project. While foundry stays our primary tool for contract development, hardhat allows us to test e.g. JSON / metadata related features of the contracts. After installing all js dependencies (`yarn`), you can execute the hardhat tests like:

`yarn hardhat test --network hardhat`

## Deployment

### General config

- The deploy script we're using is located in `script/IPNFT.sol`
- Copy `.env.example` to `.env`
- To deploy on a testnet, set the deployer's `PRIVATE_KEY` variable in the `.env` file. This can be exported from Metamask.
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.

### Deploy local development or fixture setup

- Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC. You can also use the ganache node from docker, see above.
- Run `anvil -h 0.0.0.0` in a terminal window and keep it running
- Use `cast` (which is part of Foundry) to query/manipulate your deployed contract. Find out more here: <https://book.getfoundry.sh/cast/>

We've got 2 scripts that deploy all contracts at once (`Dev.s.sol`) and create a base state(`Fixture.s.sol`)

To just deploy all contracts (using the default mnemonic's first account is used ), run `forge script script/Dev.s.sol:DevScript --fork-url $ANVIL_RPC_URL --broadcast -vvvv`

Alternatively, `Fixture.s.sol` deploys all contracts to a local node and also creates a base state for devs. It uses the 3 first accounts from the default mnemonic. Run `forge script script/Fixture.s.sol:FixtureScript --fork-url $ANVIL_RPC_URL --broadcast -vvvv` to

- Deploy all contracts as #0
- Issue one Mintpass by #0 to #1
- Mint an IP-NFT to #1
- Let #1 sell that IP-NFT to #2

### Deploy to Goerli Testnet

The easiest way to deploy contracts without exposing a local private key is the thirdweb. Here's how you initialize the process from the root folder of any web3 app: `npx thirdweb@latest deploy`

If you like to do it manually, we got you covered:

1. Make sure you have a private key in your `.env` file that has Goerli Testnet ETH on it. Otherwise you won't be able to deploy a contract because of insufficient funds.
2. Run `source .env` to get the ENV variables into your current terminal session.
3. Deploy IPNFT `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv`
4. Deploy sales contract `forge script script/SchmackoSwap.s.sol:SchmackoSwapScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv`
5. alternatively get an etherscan key to verify the contract during deployment `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY --broadcast -vvvv` .
