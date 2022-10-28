const path = require("node:path");
require('dotenv').config({
    debug: true,
    path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
    network: 'goerli',
    ipnft: {
        address: "0xA1C301D77f701037F491C074e1bD9d4ac24CF5e5",
        startBlock: 7850325,
    },
    schmackoSwap: {
        address: "0x3C5c513f51Fb10eC8F546ff127074EBC29F3a24c",
        startBlock: 7850325,
    },
};

