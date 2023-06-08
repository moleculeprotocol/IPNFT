# Tests

all code is tested with foundry tests

we're additionally testing upgrade paths for the contracts using OpenZeppelin's hardhat plugins. A rough overview of a fresh testing checkout should therefore be:

```
yarn
forge i
forge b
forge t
yarn hardhat test --network hardhat
```

## Local Setup

all instructions can be found on README.md. In a nutshell you should be able to get a full suite setup including a subgraph running by

```
docker compose up
./setupLocal.sh --fixture
cd subgraph
yarn abis
yarn prepare:local
yarn build
yarn create:local
yarn deploy:local
```

## Coverage

2023-06-08

| File                                     | % Lines         | % Statements    | % Branches     | % Funcs        |
| ---------------------------------------- | --------------- | --------------- | -------------- | -------------- |
| src/BioPriceFeed.sol                     | 100.00% (4/4)   | 100.00% (5/5)   | 100.00% (0/0)  | 100.00% (2/2)  |
| src/HeadlessDispenser.sol                | 0.00% (0/4)     | 0.00% (0/4)     | 0.00% (0/4)    | 0.00% (0/2)    |
| src/IPNFT.sol                            | 75.00% (30/40)  | 75.61% (31/41)  | 85.71% (12/14) | 64.29% (9/14)  |
| src/Mintpass.sol                         | 75.76% (25/33)  | 77.14% (27/35)  | 62.50% (10/16) | 78.57% (11/14) |
| src/Molecules.sol                        | 100.00% (14/14) | 100.00% (16/16) | 100.00% (2/2)  | 100.00% (7/7)  |
| src/Permissioner.sol                     | 87.50% (7/8)    | 90.00% (9/10)   | 100.00% (2/2)  | 60.00% (3/5)   |
| src/SalesShareDistributor.sol            | 94.87% (37/39)  | 95.56% (43/45)  | 94.44% (17/18) | 71.43% (5/7)   |
| src/SchmackoSwap.sol                     | 88.24% (30/34)  | 81.40% (35/43)  | 83.33% (15/18) | 75.00% (6/8)   |
| src/Synthesizer.sol                      | 80.00% (12/15)  | 83.33% (15/18)  | 100.00% (4/4)  | 66.67% (2/3)   |
| src/TimelockedToken.sol                  | 82.76% (24/29)  | 83.87% (26/31)  | 100.00% (6/6)  | 58.33% (7/12)  |
| src/crowdsale/CrowdSale.sol              | 98.81% (83/84)  | 98.81% (83/84)  | 95.00% (38/40) | 92.86% (13/14) |
| src/crowdsale/LockingCrowdSale.sol       | 100.00% (23/23) | 100.00% (24/24) | 100.00% (6/6)  | 100.00% (6/6)  |
| src/crowdsale/StakedLockingCrowdSale.sol | 96.00% (48/50)  | 96.30% (52/54)  | 88.89% (16/18) | 80.00% (8/10)  |
