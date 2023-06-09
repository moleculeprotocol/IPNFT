require('@openzeppelin/hardhat-upgrades')
require('@nomicfoundation/hardhat-foundry')

const config = {
  solidity: {
    version: '0.8.18',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {},
  defaultNetwork: 'localhost'
}

module.exports = config
