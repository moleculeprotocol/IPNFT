const path = require("node:path");
require('dotenv').config({
    debug: true,
    path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
    network: "goerli",
    ipnft: {
        address: "0x36444254795ce6E748cf0317EEE4c4271325D92A",
        startBlock: 8151797
    },
    schmackoSwap: {
        address: "0x2b3e3F64bEe5E184981836d0599d51935d669701",
        startBlock: 8811319
    },
    mintpass: {
        address: "0xAf0f99dcC64E8a6549d32013AC9f2C3FA7834688",
        startBlock: 8151797
    },
    fractionalizer: {
        address: '0xAa3a8758214fe7d90557310cFB42A7f69755aCbf',
        startBlock: 8919444
    }
};

