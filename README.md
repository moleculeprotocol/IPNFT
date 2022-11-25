# IPNFT

Template for NFT contracts tokenizing IP.

## Deployments

### Goerli

- IP-NFT <https://goerli.etherscan.io/address/0x5fbdb2315678afecb367f032d93f642f64180aa3#code>
- SchmackoSwap <https://goerli.etherscan.io/address/0xe7f1725e7734ce288f8367e1bb143e90bb3f0512#code>
- The Graph: <https://api.thegraph.com/subgraphs/name/elmariachi111/schrotti-galoppi-schmacko-1>

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

### Deploy contract

#### General config

- The deploy script we're using is located in `script/IPNFT.sol`
- Copy `.env.example` to `.env`
- Set the `PRIVATE_KEY` variable in the `.env`. This is the private key for the address you're deploying the contract with. For testing you can generate a private key on your command line: `openssl rand -hex 32`.
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.

#### Deploy everything at once to a local `anvil` node

1. Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC.
2. Run `anvil -h 0.0.0.0` in a terminal window and keep it running. You will see similar output to this:

![CleanShot 2022-08-14 at 15 15 12](https://user-images.githubusercontent.com/86414213/184538794-d682d4a0-1ffc-4113-a7c5-e9dc6adb8268.png)

3. Take one of the private keys you get and insert them into the `.env` file at `PRIVATE_KEY`.
4. Run `source .env` to get the ENV variables into your current terminal session.
5. Run `forge script script/Dev.s.sol:DevScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` to deploy the contracts to your local `anvil` node.
6. If the deployment was successful you get output similar to this:

![CleanShot 2022-08-14 at 15 23 03](https://user-images.githubusercontent.com/86414213/184539154-3ddc46d3-4083-4c58-a401-f7a1dce2be7e.png)

7. Use `cast` (which is part of Foundry) to query/manipulate your deployed contract. Find out more here: <https://book.getfoundry.sh/cast/>

#### Deploy local fixture setup

Fixture.s.sol is script that deploys all contracts to a local node (similiar like Dev.s.sol) but it also includes commands to create a "base state", i.e.:

- One Mintpass has been minted to Bob
- Bob has minted an IP-NFT
- Bob has sold that IP-NFT to Alice
This Fixture script is especially useful to test the subgraph.

Run `forge script script/Fixture.s.sol:FixtureScript --fork-url $ANVIL_RPC_URL --mnemonic-passphrases $MNEMONIC --broadcast -vvvv --unlocked --sender $DEPLOYER_ADDRESS`

#### Deploy to Goerli Testnet

The easiest way to deploy contracts without exposing a local private key is the thirdweb. Here's how you initialize the process from the root folder of any web3 app: `npx thirdweb@latest deploy`

If you like to do it manually, we got you covered:

1. Make sure you have a private key in your `.env` file that has Goerli Testnet ETH on it. Otherwise you won't be able to deploy a contract because of insufficient funds.
2. Run `source .env` to get the ENV variables into your current terminal session.
3. Deploy IPNFT `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv`
4. Deploy sales contract `forge script script/SchmackoSwap.s.sol:SchmackoSwapScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv`
5. alternatively get an etherscan key to verify the contract during deployment `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY --broadcast -vvvv` .
