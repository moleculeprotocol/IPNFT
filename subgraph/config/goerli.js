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
  tokenizer: {
    address: '0xb12494eeA6B992d0A1Db3C5423BE7a2d2337F58c',
    startBlock: 9142681
  },
  crowdSale: {
    address: '0xD8eB64aB24485fce141f49EC9a6808F37E82d974',
    startBlock: 9847268
  },
  stakedLockingCrowdSale: {
    address: '0x46c3369dece07176ad7164906d3593aa4c126d35',
    startBlock: 9168705
  },
  termsAcceptedPermissioner: {
    address: '0xd735d9504cce32F2cd665b779D699B4157686fcd',
    startBlock: 9417050
  }
}
