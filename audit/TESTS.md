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

more instructions can be found on README.md

## Coverage

2023-05-24

| File                                    | % Lines         | % Statements    | % Branches     | % Funcs        |
| --------------------------------------- | --------------- | --------------- | -------------- | -------------- |
| src/BioPriceFeed.sol                    | 100.00% (4/4)   | 100.00% (5/5)   | 100.00% (0/0)  | 100.00% (2/2)  |
| src/FractionalizedToken.sol             | 100.00% (15/15) | 100.00% (15/15) | 100.00% (2/2)  | 100.00% (8/8)  |
| src/Fractionalizer.sol                  | 80.00% (24/30)  | 83.78% (31/37)  | 80.00% (8/10)  | 83.33% (5/6)   |
| src/IPNFT.sol                           | 69.57% (32/46)  | 70.21% (33/47)  | 77.78% (14/18) | 71.43% (10/14) |
| src/Mintpass.sol                        | 75.76% (25/33)  | 77.14% (27/35)  | 62.50% (10/16) | 78.57% (11/14) |
| src/Permissioner.sol                    | 87.50% (7/8)    | 90.00% (9/10)   | 100.00% (2/2)  | 60.00% (3/5)   |
| src/SalesShareDistributor.sol           | 94.87% (37/39)  | 95.56% (43/45)  | 94.44% (17/18) | 71.43% (5/7)   |
| src/SchmackoSwap.sol                    | 89.47% (34/38)  | 84.31% (43/51)  | 86.36% (19/22) | 75.00% (6/8)   |
| src/crowdsale/CrowdSale.sol             | 93.90% (77/82)  | 94.05% (79/84)  | 84.21% (32/38) | 92.86% (13/14) |
| src/crowdsale/StakedVestedCrowdSale.sol | 93.18% (41/44)  | 93.75% (45/48)  | 80.00% (16/20) | 100.00% (6/6)  |
| src/crowdsale/VestedCrowdSale.sol       | 92.31% (24/26)  | 92.59% (25/27)  | 85.71% (12/14) | 100.00% (5/5)  |
