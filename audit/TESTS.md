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

2023-05-24

| File                                    | % Lines         | % Statements    | % Branches     | % Funcs        |
| --------------------------------------- | --------------- | --------------- | -------------- | -------------- |
| src/BioPriceFeed.sol                    | 100.00% (4/4)   | 100.00% (5/5)   | 100.00% (0/0)  | 100.00% (2/2)  |
| src/FractionalizedToken.sol             | 100.00% (14/14) | 100.00% (16/16) | 100.00% (2/2)  | 100.00% (7/7)  |
| src/Fractionalizer.sol                  | 68.42% (13/19)  | 72.73% (16/22)  | 83.33% (5/6)   | 60.00% (3/5)   |
| src/IPNFT.sol                           | 69.57% (32/46)  | 70.21% (33/47)  | 77.78% (14/18) | 71.43% (10/14) |
| src/Mintpass.sol                        | 75.76% (25/33)  | 77.14% (27/35)  | 62.50% (10/16) | 78.57% (11/14) |
| src/Permissioner.sol                    | 87.50% (7/8)    | 90.00% (9/10)   | 100.00% (2/2)  | 60.00% (3/5)   |
| src/SalesShareDistributor.sol           | 94.87% (37/39)  | 95.56% (43/45)  | 94.44% (17/18) | 71.43% (5/7)   |
| src/SchmackoSwap.sol                    | 89.47% (34/38)  | 84.31% (43/51)  | 86.36% (19/22) | 75.00% (6/8)   |
| src/crowdsale/CrowdSale.sol             | 98.61% (71/72)  | 98.63% (72/73)  | 94.12% (32/34) | 92.31% (12/13) |
| src/crowdsale/StakedVestedCrowdSale.sol | 95.24% (40/42)  | 95.45% (42/44)  | 81.25% (13/16) | 85.71% (6/7)   |
| src/crowdsale/VestedCrowdSale.sol       | 94.74% (18/19)  | 94.74% (18/19)  | 90.00% (9/10)  | 100.00% (4/4)  |
