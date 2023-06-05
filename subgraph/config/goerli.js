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
  fractionalizer: {
    address: '0x593ED28cb4E8d143e16D83D151a2CC01fDa10B0A',
    startBlock: 9099340
  },
  stakedLockingCrowdSale: {
    address: '0xFa7e83f13a833E688c7b45c7380D72c97133e16F',
    startBlock: 9099340
  },
  termsAcceptedPermissioner: {
    address: '0xaC17101C598e8D8567a158b773bF76d9CDDdCE31',
    startBlock: 9044965
  }
}
