const path = require('node:path')
require('dotenv').config({
  debug: true,
  path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
  network: 'goerli',
  ipnft: {
    address: '0x36444254795ce6E748cf0317EEE4c4271325D92A',
    startBlock: 8151797
  },
  schmackoSwap: {
    address: '0x2b3e3F64bEe5E184981836d0599d51935d669701',
    startBlock: 8811319
  },
  mintpass: {
    address: '0xAf0f99dcC64E8a6549d32013AC9f2C3FA7834688',
    startBlock: 8151797
  },
  fractionalizer: {
    address: '0x00214fbB81820fEc544A9cF318CF87eDA432F5e3',
    startBlock: 9044965
  },
  stakedVestedCrowdSale: {
    address: '0x04A44702Bc07De65EA721aEb32d836D9C2d1d2a9',
    startBlock: 9087462
  },
  termsAcceptedPermissioner: {
    address: '0xaC17101C598e8D8567a158b773bF76d9CDDdCE31',
    startBlock: 9044965
  }
}
