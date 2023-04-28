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

2023-04-28

| File                        | % Lines        | % Statements   | % Branches     | % Funcs        |
| --------------------------- | -------------- | -------------- | -------------- | -------------- |
| src/FractionalizedToken.sol | 100.00% (3/3)  | 100.00% (3/3)  | 100.00% (0/0)  | 100.00% (2/2)  |
| src/Fractionalizer.sol      | 82.50% (66/80) | 82.02% (73/89) | 85.71% (24/28) | 82.35% (14/17) |
| src/IPNFT.sol               | 70.21% (33/47) | 70.83% (34/48) | 77.78% (14/18) | 71.43% (10/14) |
| src/SchmackoSwap.sol        | 89.47% (34/38) | 84.31% (43/51) | 86.36% (19/22) | 75.00% (6/8)   |
