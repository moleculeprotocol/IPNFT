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

2023-07-28

| File                                     | % Lines         | % Statements    | % Branches     | % Funcs        |
| ---------------------------------------- | --------------- | --------------- | -------------- | -------------- |
| src/BioPriceFeed.sol                     | 100.00% (4/4)   | 100.00% (5/5)   | 100.00% (0/0)  | 100.00% (2/2)  |
| src/IPNFT.sol                            | 78.05% (32/41)  | 77.27% (34/44)  | 85.71% (12/14) | 78.57% (11/14) |
| src/IPToken.sol                          | 100.00% (14/14) | 100.00% (18/18) | 100.00% (2/2)  | 100.00% (7/7)  |
| src/Mintpass.sol                         | 75.76% (25/33)  | 78.05% (32/41)  | 62.50% (10/16) | 78.57% (11/14) |
| src/Permissioner.sol                     | 87.50% (7/8)    | 90.91% (10/11)  | 100.00% (2/2)  | 83.33% (5/6)   |
| src/SalesShareDistributor.sol            | 94.87% (37/39)  | 95.56% (43/45)  | 94.44% (17/18) | 71.43% (5/7)   |
| src/SchmackoSwap.sol                     | 88.24% (30/34)  | 80.00% (36/45)  | 83.33% (15/18) | 75.00% (6/8)   |
| src/SignedMintAuthorizer.sol             | 71.43% (5/7)    | 80.00% (8/10)   | 100.00% (0/0)  | 75.00% (3/4)   |
| src/TimelockedToken.sol                  | 82.76% (24/29)  | 76.47% (26/34)  | 100.00% (6/6)  | 58.33% (7/12)  |
| src/Tokenizer.sol                        | 76.47% (13/17)  | 78.95% (15/19)  | 100.00% (4/4)  | 50.00% (2/4)   |
| src/crowdsale/CrowdSale.sol              | 98.81% (83/84)  | 98.82% (84/85)  | 95.00% (38/40) | 92.86% (13/14) |
| src/crowdsale/LockingCrowdSale.sol       | 100.00% (24/24) | 100.00% (25/25) | 100.00% (6/6)  | 100.00% (7/7)  |
| src/crowdsale/StakedLockingCrowdSale.sol | 94.23% (49/52)  | 94.64% (53/56)  | 88.89% (16/18) | 80.00% (8/10)  |
