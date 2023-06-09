const path = require('node:path')
require('dotenv').config({
  debug: true,
  path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
  network: 'goerli',
  ipnft: {
    address: '0xaf7358576C9F7cD84696D28702fC5ADe33cce0e9',
    startBlock: 9099302
  },
  schmackoSwap: {
    address: '0x67D8ed102E2168A46FA342e39A5f7D16c103Bd0d',
    startBlock: 9099302
  },
  mintpass: {
    address: '0xAf0f99dcC64E8a6549d32013AC9f2C3FA7834688',
    startBlock: 8151797
  },
  synthesizer: {
    address: '0xb12494eeA6B992d0A1Db3C5423BE7a2d2337F58c',
    startBlock: 9142681
  },
  stakedLockingCrowdSale: {
    address: '0x5b161D131f8254A2df91e9382F6E5973aB4eD0f9',
    startBlock: 9142681
  },
  termsAcceptedPermissioner: {
    address: '0x0045723801561079d94f0Bb1B65f322078E52635',
    startBlock: 9148511
  }
}
