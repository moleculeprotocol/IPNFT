const path = require("node:path");
require('dotenv').config({
    debug: true,
    path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
    network: 'mainnet',
    ipnft: {
        address: process.env.IPNFT_ADDRESS,
        startBlock: 0,
    },
    simpleOpenSea: {
        address: process.env.SOS_ADDRESS,
        startBlock: 0,
    },
};
