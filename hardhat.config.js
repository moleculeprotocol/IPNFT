require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-foundry");

//import example from "./tasks/example";

//task("example", "Example task").setAction(example);

const config = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {},

  defaultNetwork: "localhost",
};

module.exports = config;
