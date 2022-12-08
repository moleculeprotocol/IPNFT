const fs = require("node:fs");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-preprocessor");
require('hardhat-watcher')
const { HardhatUserConfig, task } = require("hardhat/config");

//import example from "./tasks/example";

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

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
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
  },
  networks: {},
  //  This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
  watcher: {
    tests: {
      tasks: [{ command: 'test', params: { testFiles: ['{path}'] } }],
      files: ['./contracts', './test'],
      ignoredFiles: ['**/.vscode'],
      verbose: true,
      clearOnStart: true,
      start: 'echo Running my tasks now..',
    },
  },
  defaultNetwork: "localhost",
};

module.exports = config;
