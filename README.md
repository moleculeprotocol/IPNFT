# IPNFT

Template for NFT contracts tokenizing IP.

## Deployments

### Mainnet

- IPNFT: <https://etherscan.io/address/0x0dccd55fc2f116d0f0b82942cd39f4f6a5d88f65#code>
- Schmackoswap: <https://etherscan.io/address/0xc09b8577c762b5e97a7d640f242e1d9bfaa7eb9d#code>
- Mintpass: <https://etherscan.io/address/0x0ecff38f41ecd1e978f1443ed96c0c22497d73cb>
- The Graph: <https://api.thegraph.com/subgraphs/name/moleculeprotocol/ip-nft-mainnet>

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

- The deploy scripts are located in `script`
- Copy `.env.example` to `.env`
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.
- Set a moderator address that's going to be enabled to issue and revoke mintpasses

### Deploy for local development

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

### Deploy to a live network

The easiest way to deploy contracts without exposing a local private key is the thirdweb. Here's how you initialize the process from the root folder: `npx thirdweb@latest deploy`

#### Deploy manually

The `Deploy.s.sol` script deploys all three contracts (IPNFT, Schmackoswap and Mintpass) manually and sets up a first moderator (defined by the `MODERATOR_ADDRESS` env var). Make sure that you're using the correct moderator address for the network you're deploying to.

You _can_ place required env vars in your `.env` file and run `source .env` to get them into your current terminal session or provide them when invoking the command.

1. Make sure you have the private key for your deployer account at hand and that it has ETH on the target network on it.
2. run `forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --interactives 1 --sender <deployer address> --broadcast -vvvv`
3. Paste the private key for the deployer account
4. to verify the contract during deployment, get an Etherscan API key and add `--verify --etherscan-api-key $ETHERSCAN_API_KEY` to the command.

> This is _not_ possible at the moment, but stay tuned:  
> Alternatively, start Truffle Dashboard suite and use its RPC URL to sign off transactions with Metamask:
> `npx truffle dashboard` > `MODERATOR_ADDRESS=<first moderator> forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:24012/rpc --sender <deployer address> --froms <deployer address> --broadcast -vvvv`

### Manually Verify contracts on Etherscan

full docs: https://book.getfoundry.sh/reference/forge/forge-verify-contract

`forge verify-contract --chain-id 5 <address> IPNFT`

or, if you need to verify with constructor arguments:

`forge verify-contract --chain-id 5 <address> Mintpass --constructor-args $(cast abi-encode "constructor(address)" "0xabcdef")`

## Interacting with cast

when having an RPC_URL in your local env, you can simply call view functions like this:
`cast call $IPNFT_ADDRESS "tokenURI(uint256)" 1 | cast --to-ascii`
