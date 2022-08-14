# IPNFT

Template for NFT contracts tokenizing IP.

## Deployments

- Goerli Testnet: https://goerli.etherscan.io/address/0x9ac15c603e20f4402edead5e761adc0a8f469648#code

## Installation

To work with this repository you have to install Foundry (https://getfoundry.sh).

Run the following command in your terminal, then follow the onscreen instructions (macOS and Linux):

`curl -L https://foundry.paradigm.xyz | bash`

The above command will install `foundryup`. Then install Foundry by running `foundryup` in your terminal.

(Check out the Foundry book for a Windows installation guide: https://book.getfoundry.sh)

## Usage

### Run tests

Run `forge test`

### Run tests and get a gas usage report

Run `forge test --gas-report`

![CleanShot 2022-08-14 at 15 08 17](https://user-images.githubusercontent.com/86414213/184538476-20c8ff24-4714-44bf-a618-f6176cabd03c.png)

### Deploy contract

#### General config

- The deploy script we're using is located in `script/IPNFT.sol`
- Copy `.env.example` to `.env` 
- Set the `PRIVATE_KEY` variable in the `.env`. This is the private key for the address you're deploying the contract with. For testing you can generate a private key on your command line: `openssl rand -hex 32`.
- Set the `ETHERSCAN_KEY` if you want to verify deployed contracts on Etherscan.

#### Deploy to a local `anvil` node

1. Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC.
2. Run `anvil` in a terminal window and keep it running. You will see similar output to this:
![CleanShot 2022-08-14 at 15 15 12](https://user-images.githubusercontent.com/86414213/184538794-d682d4a0-1ffc-4113-a7c5-e9dc6adb8268.png)

3. Take one of the private keys you get and insert them into the `.env` file at `PRIVATE_KEY`.
4. Run `source .env` to get the ENV variables into your current terminal session.
5. Run `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` to deploy the contract to your local `anvil` node.
6. If the deployment was successful you get output similar to this:
![CleanShot 2022-08-14 at 15 23 03](https://user-images.githubusercontent.com/86414213/184539154-3ddc46d3-4083-4c58-a401-f7a1dce2be7e.png)
7. Using `cast` (which is part of Foundry) you can now query/manipulate your deployed contract. Find out more here: https://book.getfoundry.sh/cast/

#### Deploy to Goerli Testnet

1. Make sure you have a private key in your `.env` file that has Goerli Testnet ETH on it. Otherwise you won't be able to deploy a contract because of insufficient funds.
2. Run `source .env` to get the ENV variables into your current terminal session.
3. Run `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` or if you want to also verify the contract on Etherscan `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY --broadcast -vvvv` .
