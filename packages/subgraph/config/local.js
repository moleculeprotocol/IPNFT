const path = require('node:path')
require('dotenv').config({
  debug: true,
  path: path.resolve(process.cwd(), '../.env.example')
})

module.exports = {
  network: 'mainnet',
  ipnft: {
    address: process.env.IPNFT_ADDRESS,
    startBlock: 0
  },
  schmackoSwap: {
    address: process.env.SOS_ADDRESS,
    startBlock: 0
  },
  tokenizer: {
    address: process.env.TOKENIZER_ADDRESS,
    startBlock: 0
  },
  crowdSale: {
    address: process.env.PLAIN_CROWDSALE_ADDRESS,
    startBlock: 0
  },
  stakedLockingCrowdSale: {
    address: process.env.STAKED_LOCKING_CROWDSALE_ADDRESS,
    startBlock: 0
  },
  termsAcceptedPermissioner: {
    address: process.env.TERMS_ACCEPTED_PERMISSIONER_ADDRESS,
    startBlock: 0
  }
}
