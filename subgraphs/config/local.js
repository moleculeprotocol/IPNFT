const path = require('node:path');
require('dotenv').config({
  debug: true,
  path: path.resolve(process.cwd(), '../.env')
});

module.exports = {
  networkL1: 'mainnet',
  networkL2: 'optimism',
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
  fractionalizerL2Dispatcher: {
    address: process.env.FRACTIONALIZERL2_DISPATCHER_ADDRESS,
    startBlock: 0
  },
  //   TODO: To be added once deployed
  fractionalizer: {
    address: process.env.FRACTIONALIZERL2_ADDRESS,
    startBlock: 0
  }
};
