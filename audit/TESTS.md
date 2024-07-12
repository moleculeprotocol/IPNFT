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

2024-07-12

| File                                     | % Lines         | % Statements     | % Branches     | % Funcs        |
| ---------------------------------------- | --------------- | ---------------- | -------------- | -------------- |
| src/BioPriceFeed.sol                     | 100.00% (6/6)   | 100.00% (7/7)    | 100.00% (0/0)  | 100.00% (3/3)  |
| src/IPNFT.sol                            | 90.48% (38/42)  | 89.58% (43/48)   | 85.71% (12/14) | 80.00% (12/15) |
| src/IPToken.sol                          | 100.00% (16/16) | 100.00% (24/24)  | 100.00% (4/4)  | 100.00% (7/7)  |
| src/Mintpass.sol                         | 77.14% (27/35)  | 76.09% (35/46)   | 68.75% (11/16) | 80.00% (12/15) |
| src/Permissioner.sol                     | 87.50% (7/8)    | 90.91% (10/11)   | 100.00% (2/2)  | 66.67% (4/6)   |
| src/SalesShareDistributor.sol            | 97.37% (37/38)  | 98.00% (49/50)   | 93.75% (15/16) | 85.71% (6/7)   |
| src/SchmackoSwap.sol                     | 88.24% (30/34)  | 80.85% (38/47)   | 83.33% (15/18) | 75.00% (6/8)   |
| src/SignedMintAuthorizer.sol             | 70.00% (7/10)   | 76.92% (10/13)   | 100.00% (0/0)  | 80.00% (4/5)   |
| src/TimelockedToken.sol                  | 82.76% (24/29)  | 80.00% (32/40)   | 100.00% (6/6)  | 58.33% (7/12)  |
| src/Tokenizer.sol                        | 100.00% (34/34) | 100.00% (47/47)  | 90.00% (9/10)  | 90.91% (10/11) |
| src/crowdsale/CrowdSale.sol              | 98.92% (92/93)  | 99.09% (109/110) | 95.45% (42/44) | 93.75% (15/16) |
| src/crowdsale/LockingCrowdSale.sol       | 100.00% (24/24) | 100.00% (28/28)  | 100.00% (6/6)  | 100.00% (7/7)  |
| src/crowdsale/StakedLockingCrowdSale.sol | 94.23% (49/52)  | 95.08% (58/61)   | 88.89% (16/18) | 80.00% (8/10)  |
