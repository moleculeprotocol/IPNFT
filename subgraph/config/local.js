require('dotenv').config();

module.exports = {
    network: 'mainnet',
    ipnft: {
        address: process.env.ANVIL_IPNFT_CONTRACT_ADDRESS,
        startBlock: 0,
    },
    simpleOpenSea: {
        address: process.env.ANVIL_SIMPLEOPENSEA_CONTRACT_ADDRESS,
        startBlock: 0,
    },
};
