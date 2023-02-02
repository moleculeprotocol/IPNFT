# IPNFT

IP-NFTs allow their users to tokenize intellectual property. This repo contains code for IP-NFT smart contracts and compatible subgraphs. Details on how IP-NFTs are minted, their purpose and applications [can be found here](https://docs.molecule.to)

## Deployments

### Mainnet

| Contract     | Address                                                                                                                     | Actions                                                                                                                                                                                                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IP-NFT       | [0x0dccd55fc2f116d0f0b82942cd39f4f6a5d88f65](https://etherscan.io/address/0x0dccd55fc2f116d0f0b82942cd39f4f6a5d88f65#code>) | <a href="https://thirdweb.com/ethereum/0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65&theme=dark&chainId=1" alt="View contract" /></a> |
| SchmackoSwap | [0xc09b8577c762b5e97a7d640f242e1d9bfaa7eb9d](https://etherscan.io/address/0xc09b8577c762b5e97a7d640f242e1d9bfaa7eb9d#code)  | <a href="https://thirdweb.com/ethereum/0xc09b8577c762b5E97a7D640F242E1D9bfAa7EB9d?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0xc09b8577c762b5E97a7D640F242E1D9bfAa7EB9d&theme=dark&chainId=1" alt="View contract" /></a> |
| Mintpass     | [0x0ecff38f41ecd1e978f1443ed96c0c22497d73cb](https://etherscan.io/address/0x0ecff38f41ecd1e978f1443ed96c0c22497d73cb#code)  | <a href="https://thirdweb.com/ethereum/0x0Ecff38F41EcD1E978f1443eD96c0C22497d73cB?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0x0Ecff38F41EcD1E978f1443eD96c0C22497d73cB&theme=dark&chainId=1" alt="View contract" /></a> |

- Subgraph: <https://api.thegraph.com/subgraphs/name/moleculeprotocol/ip-nft-mainnet>

---

### Goerli

| Contract     | Address                                                                                                                            | Actions                                                                                                                                                                                                                                                                                               |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IP-NFT       | [0x36444254795ce6E748cf0317EEE4c4271325D92A](https://goerli.etherscan.io/address/0x36444254795ce6E748cf0317EEE4c4271325D92A#code>) | <a href="https://thirdweb.com/goerli/0x36444254795ce6E748cf0317EEE4c4271325D92A?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0x36444254795ce6E748cf0317EEE4c4271325D92A&theme=dark&chainId=5" alt="View contract" /></a> |
| SchmackoSwap | [0x2365BEDC04Fb449718D3143C88aF73ad83d7b9B6](https://goerli.etherscan.io/address/0x2365BEDC04Fb449718D3143C88aF73ad83d7b9B6#code)  | <a href="https://thirdweb.com/goerli/0x2365BEDC04Fb449718D3143C88aF73ad83d7b9B6?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0x2365BEDC04Fb449718D3143C88aF73ad83d7b9B6&theme=dark&chainId=5" alt="View contract" /></a> |
| Mintpass     | [0xaf0f99dcc64e8a6549d32013ac9f2c3fa7834688](https://goerli.etherscan.io/address/0xaf0f99dcc64e8a6549d32013ac9f2c3fa7834688#code)  | <a href="https://thirdweb.com/goerli/0xaf0f99dcc64e8a6549d32013ac9f2c3fa7834688?utm_source=contract_badge" target="_blank"><img width="200" height="45" src="https://badges.thirdweb.com/contract?address=0xaf0f99dcc64e8a6549d32013ac9f2c3fa7834688&theme=dark&chainId=5" alt="View contract" /></a> |

- HeadlessDispenser <https://goerli.etherscan.io/address/0x0F1Bd197c5dCC6bC7E8025037a7780010E2Cd22A#code>
- Subgraph: <https://api.thegraph.com/subgraphs/name/dorianwilhelm/ip-nft-subgraph-goerli/graphql>

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

### Hardhat tests

We also added a basic hardhat environment to this project. While foundry stays our primary tool for contract development, hardhat allows us to test e.g. JSON / metadata related features of the contracts. After installing all js dependencies (`yarn`), you can execute the hardhat tests like:

`yarn hardhat test --network hardhat`

## Deployment

### General config

- The deploy scripts are located in `script`
- Copy `.env.example` to `.env`
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.
- Set a moderator address that's going to be enabled to issue and revoke mintpasses (only needed for "real" deployments)

You can place required env vars in your `.env` file and run `source .env` to get them into your current terminal session or provide them when invoking the command.

### Deploy for local development

- Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC. You can also use the ganache node from docker, see the [accompanying README in the `subgraph` folder](./subgraph/README.md).
- Run `anvil -h 0.0.0.0` in a terminal window and keep it running

To just deploy all contracts using the default mnemonic's first account, run `forge script script/Dev.s.sol:DevScript --fork-url $ANVIL_RPC_URL --broadcast -vvvv`

Alternatively, `Fixture.s.sol` deploys all contracts to a local node and also creates a base state for frontend devs. It uses the 3 first accounts from the default mnemonic. Run `forge script script/Fixture.s.sol:FixtureScript --fork-url $ANVIL_RPC_URL --broadcast -vvvv` to

- Deploy all contracts as #0
- Issue one Mintpass by #0 to #1
- Mint an IP-NFT to #1
- Let #1 sell that IP-NFT to #2

### Deploy to a live network

The easiest way to deploy contracts without exposing a local private key is the thirdweb. Here's how you initialize the process from the root folder: `npx thirdweb@latest deploy`

To manually broadcast a bundle of deploy transactions, you can use `Deploy.s.sol`. It deploys all three relevant contracts (IPNFT, Schmackoswap and Mintpass) and sets up a first moderator (defined by the `MODERATOR_ADDRESS` env var). Make sure that you're using the correct moderator address for the network you're deploying to.

1. Make sure you have the private key for your deployer account at hand and that it has ETH on the target network on it.
2. Run `forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --interactives 1 --sender <deployer address> --broadcast -vvvv`
3. Paste the private key for the deployer account
4. to verify the contract during deployment, get an Etherscan API key and add `--verify --etherscan-api-key $ETHERSCAN_API_KEY` to the command.

> This is _not_ possible at the moment, but stay tuned:  
> Alternatively, start Truffle Dashboard suite and use its RPC URL to sign off transactions with Metamask:
> `npx truffle dashboard` > `MODERATOR_ADDRESS=<first moderator> forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:24012/rpc --sender <deployer address> --froms <deployer address> --broadcast -vvvv`

### Testing a manual upgrade

deploy the old version

```
forge script script/IPNFT.s.sol --rpc-url $ANVIL_RPC_URL -vvvv --broadcast --private-key ...
```

switch your branch or get the new contract impl at hand

```
PROXY_ADDRESS=<the proxy address> forge script script/UpgradeImplementation.s.sol --rpc-url $ANVIL_RPC_URL --sender <proxy-owner-address>
```

(or use your pk and --broadcast to submit it)

### Manually Verify contracts on Etherscan

full docs: https://book.getfoundry.sh/reference/forge/forge-verify-contract

`forge verify-contract --chain-id 5 <address> IPNFT`

or, if you need to verify with constructor arguments:

`forge verify-contract --chain-id 5 <address> Mintpass --constructor-args $(cast abi-encode "constructor(address)" "0xabcdef")`

## Interacting with cast

`cast` is another CLI command installed by Foundry and allows you to query/manipulate your deployed contracts easily. Find out more here: <https://book.getfoundry.sh/cast/>

When having an RPC_URL in your local env, you e.g. can simply call view functions like this:  
`cast call $IPNFT_ADDRESS "tokenURI(uint256)" 1 | cast --to-ascii`

### manual interaction playbook

Here are some helpful interaction examples with the contracts that you can execute from your command line. Ensure your local environment contains all contract addresses and is sourced to your terminal. We're using your local PRIVATE_KEY here

> TODO mintpass logic is not covered here

Create a reservation

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "reserve()(uint256)"`

mint an IP-NFT to the first account

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "mintReservation(address, uint256)(uint256)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 0`

approve SchmackoSwap to spend token 0

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "approve(address, uint256)()" $SOS_ADDRESS 0`

Create a Listing for 10 sample tokens

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "list(address, uint256, address, uint256)(uint256)" $IPNFT_ADDRESS 0 $ERC20_ADDRESS 10`

take note of the resulting listing id

Cancel a listing

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "cancel(uint256)()" <listingid>`

Create a new Listing (take down id)

`cast send -i $SOS_ADDRESS --private-key $PRIVATE_KEY "list(address, uint256, address, uint256)(uint256)" $IPNFT_ADDRESS 0 $ERC20_ADDRESS 10`

allow Account(1)

`cast send -i $SOS_ADDRESS "changeBuyerAllowance(uint256, address, bool)()" <listingid> 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 true`

supply Account(1) with ERC20

`cast send -i $ERC20_ADDRESS --private-key $PRIVATE_KEY "mint(address, uint256)()" 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 10`

allow SOS to spend ERC20

`cast send --i $ERC20_ADDRESS --private-key <account1 private key> "increaseAllowance(address, uint256)()" $SOS_ADDRESS 10`

let account(1) fulfill the listing

`cast send -i \$SOS_ADDRESS --private-key <account1 private key> "fulfill(uint256)()" <listingid>`
