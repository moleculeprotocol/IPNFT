const path = require('node:path');
require('dotenv').config({
  debug: true,
  path: path.resolve(process.cwd(), '../.env')
});

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
  mintpass: {
    address: process.env.MINTPASS_ADDRESS,
    startBlock: 0
  },
  fractionalizer: {
    address: process.env.FRACTIONALIZER_ADDRESS,
    startBlock: 0
  },
  stakedVestedCrowdSale: {
    address: process.env.STAKED_VESTED_CROWDSALE_ADDRESS,
    startBlock: 0
  },
  termsAcceptedPermissioner: {
    address: process.env.TERMS_ACCEPTED_PERMISSIONER_ADDRESS,
    startBlock: 0
  }
};
