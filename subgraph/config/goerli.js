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
        address: "0x2365BEDC04Fb449718D3143C88aF73ad83d7b9B6",
        startBlock: 8151797
    },
    mintpass: {
        address: "0xAf0f99dcC64E8a6549d32013AC9f2C3FA7834688",
        startBlock: 8151797
    }
};

