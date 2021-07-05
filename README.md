# IPNFT
#### A contract designed to tokenize IP

## Setting up the repo

This repo contains a [Hardhat](https://hardhat.org) development environment. We recommend using it with Yarn. You can get set up by cloning the repo locally, then installing using `yarn install` in the root directory.

This repo uses dotenv to protect secrets (private keys, API keys). There is a template called `.example.env` in the `chain` folder. It should be copied and renamed `.env`. Relevant information should be added in the relevant fields - a private key and Infura secret for the chains being used, and an Etherscan API key for contract verification.

In order to deploy anywhere other than a local devnet (which will be detailed below), the relevant section in `chain/hardhat.config.ts` should be uncommented. For example, if you wish to deploy on Goerli, uncomment the `goerli` section in `chain/hardhat.config.ts`, and make sure the relevant data is in the `.env`. We'll detail the deployment process below.

## About IPNFT

A few pointers about the contract:
* the contract file's name (the file name, not the name of the contract inside the file) is `NFTIP`, not `IPNFT` - Hardhat's compiler assumes a `.sol` file named `IPNFT` is an interface contract
* the `mint` function assumes a URI, and has three arguments: 1) the address to mint the NFT to, 2) the `tokenId` (index) of the NFT, 3) the _full URL_ of the URI - this was a decision reached with Molecule to ensure that if Molecule decided to change storage service that the previous NFTs would not be broken
*  there is a funciton called `mintWithoutTokenURI` for miniting without a URI


## Running the Tests

There is a test suite accompanying IPNFT. In order to run it, open a terminal and start a local dev (ephemeral) chain by running `yarn chain`. (Port 8545 will need to be open for this to work.) Open another terminal, and run `yarn test`, which will run the test suite.

## Deployment

### Local Deployments

If you would like to test deploying IPNFT on a local dev chain, simply run `yarn deploy:local` after you have a dev chain running on port 8545.

### Testnet and Mainnet Deployments

In order to deploy to testnets or mainnet, first make sure that you have a `.env` file in `chain/` with the relevant fields filled in (Infura and private key for the relevant chain(s) and Etherscan API key). There is a template in `chain/` called `.example.env` - you can copy it and rename it to `.env`.

Then make sure the relevant field(s) in `chain/hardhat.config.ts` are uncommented. For example, if you wish to deploy on Goerli, uncomment the `goerli` section in `chain/hardhat.config.ts`, and make sure the relevant data is in the `.env`.

There are three convenience functions provided for deployment:
* In order to deploy on Rinkeby, run `yarn deploy:rinkeby`
* In order to deploy on Goerli, run `yarn deploy:goerli`
* In order to deploy on Ethereum's mainnet, run `yarn deploy:mainnet`

There are other networks availale in the `.example.env` and `hardhat.config.ts` if desired. Similarly, `hardhat.config.ts` can be configured to run on a service other than Infura or using a local node.