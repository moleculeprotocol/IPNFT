const path = require("node:path");
require('dotenv').config({
    debug: true,
    path: path.resolve(process.cwd(), '../.env')
})

module.exports = {
    network: "goerli",
    ipnft: {
        address: "0x8c3BC5679ccD46F33D0571a248985942A817328A",
        startBlock: 8127967
    },
    schmackoSwap: {
        address: "0xC52A5d839eee47498A30b4517A573b2197F54888",
        startBlock: 8128259
    },
    mintpass: {
        address: "0x9c053F391e929dEd1F10b0240bB4fbd048Ae7949",
        startBlock: 8128057
    }
};

