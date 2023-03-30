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
- Impl 2.2 0x026fa78c956ddf29fa84371460727bac0fd6204a

- Contract Registry 0x91d6984adecadeb13f8bef2db8c4cb896210fcb1
  https://goerli.etherscan.io/address/0x91d6984adecadeb13f8bef2db8c4cb896210fcb1#code

- Fractionalizer Dispatcher L1: 0xB3bE2424FBc0A9cCb3FB5fFD5655235F21855526
  (Impl no 7 0x305786450e56856fEd3A8764a24229AA9F8Adc4B)
  <https://goerli.etherscan.io/address/0xB3bE2424FBc0A9cCb3FB5fFD5655235F21855526>

- Fractionalizer L2: 0x7DA77f8a834369dDc5e9e47407C9746Ed55C3b72
  (Impl no 1 0xd188172cf0135efb415c4b5d3531495fa373c557)
  <https://goerli-optimism.etherscan.io/address/0x7DA77f8a834369dDc5e9e47407C9746Ed55C3b72>

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

### Deployment scripts

- a fresh, proxied deployment can be created by `forge script script/IPNFT.sol`
- to rollout a new upgrade on a live network without calling the proxy's upgrade function, you can use `forge script script/UpgradeImplementation.s.sol:DeployImplementation` and invoke the upgrade function manually (e.g. from your multisig)
- for the "real" thing you'll need to add `--rpc-url` and `--private-key` and finally `--broadcast` params .

### Deploy for local development

- Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC. You can also use the ganache node from docker, see the [accompanying README in the `subgraph` folder](./subgraph/README.md).
- Run `anvil -h 0.0.0.0` in a terminal window and keep it running

To just deploy all contracts using the default mnemonic's first account, run `forge script script/dev/Dev.s.sol:DevScript --fork-url $ANVIL_RPC_URL --broadcast -vvvv`

Alternatively, `dev/Fixture.s.sol` deploys all contracts to a local node and also creates a base state for frontend devs. It uses the 3 first accounts from the default mnemonic. Run `forge script script/dev/Fixture.s.sol --fork-url $ANVIL_RPC_URL --broadcast` to setup all contracts and start a a listing and finalize the listing with `forge script script/dev/ApproveAndBuy.s.sol --fork-url $ANVIL_RPC_URL --broadcast`. See the inline comment on why these are 2 scripts.

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

### Fractionalizer

The fractionalizer consists of two contracts: The Dispatcher (`L1FractionalizerDispatcher`) lives on L1. IP-NFT owners call it to initiate a fractionalization event on L2. It checks that the IP-NFT belongs to the current user, verifies that this IP-NFT has not been fractionalized before and dispatches a message to the respective L2 contract that will issue fractions. The L2 contract (`Fractionalizer`) first checks that its been called by the L2 messaging bridge and that the call originated from the L1 contract (the dispatcher). It then verifies that the computed fraction id matches the input parameters and issues the requested amount of fractions to the IP-NFT owner on the L2 network. The dispatcher depends on a named registry (`ContractRegistry`) to resolve contract addresses and token address translations. This must be deployed before the dispatcher itself so it can be provided as a construcutor argument. For convenience we added 2 premade registries for Görli and mainnet but you can deploy and maintain fully custom ones. The fractionalization contracts are deployed as upgradeable 1967/UUPSProxies using the original OZ implementation.

#### Deploying

Note that for these deployments you'll need different RPC_URLs for L1 and L2. Also, the Optimism block explorer doesn't work with your Etherscan api key. You must log into it individually and create a dedicated api key for contract code validation.
Manual deployment order

- deploy registry for Görli
  `NETWORK=5 forge script script/DeployContractRegistry.s.sol --rpc-url $RPC_URL_L1 --broadcast -vvvv`

- deploy L1 dispatcher
  `SOS_ADDRESS=<schmackoswapOnL1> REGISTRY_ADDRESS=<registry address> forge script script/DeployFractionalizerL1.s.sol --rpc-url $RPC_URL_1 --broadcast -vvvv`

- deploy L2 fractionalizer
  `forge script script/DeployFractionalizerL2.s.sol --rpc-url $RPC_URL_L2 --broadcast -vvvv`

- set L2 address on registry
  `cast send --rpc-url $RPC_URL_L1 -i <registry address> "register(bytes32,address)" $(cast --from-utf8 "FractionalizerL2") <fractionalizer address on L2>`

- set L1 dispatcher's address on L2 fractionalizer (so it can verify incoming message calls)
  `cast send --rpc-url $RPC_URL_L2 -i <L2 fractionalizer contract> "setFractionalizerDispatcherL1(address)"  <dispatcher address on L1>`

note that the registry doesnt use strings but bytes32 as keys. To manually retrieve registered names you can convert strings to their byte32 encoded counterparts locally, like so
`cast --from-utf8 "CrossdomainMessenger"`

We also included helpers to quickly deploy updated versions of the contracts. You must call their `updateTo` functions individually, though.

- verify the L1 dispatcher impl
  `ETHERSCAN_API_KEY=<görli api key> forge verify-contract --chain-id 5 <new impl addr> FractionalizerL2Dispatcher`

- verify the L2 fractionalizer impl
  `ETHERSCAN_API_KEY=<optimism-görli api key> forge verify-contract --chain-id 420 <new_impl_addr> Fractionalizer --constructor-args $(cast abi-encode "constructor(address)" "0xB2b5841DBeF766d4b521221732F9B618fCf34A87")`

- verify an EIP1967 proxy
  `ETHERSCAN_API_KEY=... forge verify-contract --chain-id 420 <proxy address> ERC1967Proxy --constructor-args $(cast abi-encode "constructor(address,bytes)" "<initial implementation address>" "")`

#### mocking xdomain interactions so you can call the Fractionalizer's methods directly

forge script --rpc-url $ANVIL_RPC_URL script/dev/DeployMockedFractionalizer.s.sol:DeployMockedFractionalizer --private-key $PRIVATE_KEY -vvv --broadcast

> mock xdomain messenger 0x5FbDB2315678afecb367f032d93F642f64180aa3
> fractionalizer l2 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9

compute a fraction token id (you can use chisel) (originalOwner,collection,tokenid) for demonstration reasons we're using the fractionalizer NFT as collection address, this normally would be your IPNFT contract:
`keccak256(abi.encodePacked(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9, uint256(1)))`

> 0xe0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd

compute some agreement hash
`cast --format-bytes32-string "agreement"`

> 0x61677265656d656e740000000000000000000000000000000000000000000000

build the call signature / message
`cast calldata "fractionalizeUniqueERC1155(uint256,address,uint256,address,bytes32,uint256)" 0xe0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 1 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 0x61677265656d656e740000000000000000000000000000000000000000000000 100000`

> 0x327faeb2e0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd000000000000000000000000cf7ed3acca5a467e9e704c703e8d87f634fb0fc9000000000000000000000000000000000000000000000000000000000000000100000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c861677265656d656e74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000186a0

call through the mocked message sender

`cast send --rpc-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY 0x5FbDB2315678afecb367f032d93F642f64180aa3 "sendMessage(address,bytes,uint32)" "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9" 0x327faeb2e0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd000000000000000000000000cf7ed3acca5a467e9e704c703e8d87f634fb0fc9000000000000000000000000000000000000000000000000000000000000000100000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c861677265656d656e74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000186a0 1000000`

check that original owner owns 100000 fractions now

`cast call --rpc-url $ANVIL_RPC_URL 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "totalSupply(uint256)" 0xe0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd`

> 0x00000000000000000000000000000000000000000000000000000000000186a0

`cast --to-base 0x00000000000000000000000000000000000000000000000000000000000186a0 10`

> 100000

get token uri

`cast call --rpc-url $ANVIL_RPC_URL 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "uri(uint256)" 0xe0ab3d7476064dbd63263d0632e299da8528ff449841b11a29555ac405a090cd | cast --to-ascii`

after decoding from b64:

```json
{
  "name": "Fractions of 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9 / 1",
  "description": "this token represents fractions of the underlying asset",
  "decimals": 0,
  "external_url": "https://molecule.to",
  "image": "",
  "properties": {
    "collection": "0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9",
    "token_id": 1,
    "agreement_hash": "0x61677265656d656e740000000000000000000000000000000000000000000000",
    "original_owner": "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
    "supply": 100000
  }
}
```

## General: Interacting with cast

`cast` is another CLI command installed by Foundry and allows you to query/manipulate your deployed contracts easily. Find out more here: <https://book.getfoundry.sh/cast/>

When having an RPC_URL in your local env, you e.g. can simply call view functions like this:  
`cast call $IPNFT_ADDRESS "tokenURI(uint256)" 1 | cast --to-ascii`

### manual interaction playbook

Here are some helpful interaction examples with the contracts that you can execute from your command line. Ensure your local environment contains all contract addresses and is sourced to your terminal. We're using your local PRIVATE_KEY here

Manually issue 2 mintpasses to anvil address #0

`cast send -i $MINTPASS_ADDRESS --private-key $PRIVATE_KEY "batchMint(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 2`

Create a reservation

`cast send -i $IPNFT_ADDRESS --private-key $PRIVATE_KEY "reserve()(uint256)"`

mint an IP-NFT to the first account

`cast send --private-key $PRIVATE_KEY  -i $IPNFT_ADDRESS --value 0.001ether --broadcast  "mintReservation(address,uint256,uint256,string)(uint256)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 1 1 "ipfs://test"`

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

grant read access to another party

`cast send --private-key $PRIVATE_KEY  -i $IPNFT_ADDRESS "grantReadAccess(address,uint256,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 1 1680265071`
