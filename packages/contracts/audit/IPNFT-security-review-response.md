# Security Response

This response is based on the codebase state at [5199541db760b551e2b91fd7cb4dcf678970d55b](https://github.com/moleculeprotocol/IPNFT/blob/5199541db760b551e2b91fd7cb4dcf678970d55b/)

[H-01]
We have changed the `LockingCrowdSale` base contract so it doesn't allow or enforce bringing along an individual `TimelockedToken` contract. It will rather reuse these contracts and creates them when required, so these contracts are never be controlled by external entities (see `mapping(address => TimelockedToken) public lockingContracts;`)

Since we want to accept external stake _vesting_ (`ITokenVesting`) contracts to not introduce even more complexity into the broader BioDAO ecosystem, `StakedLockingCrowdSale:startSale` still allows to send along the wanted vesting contract but it only accepts contracts that have been audited / registered before.

[M-01] We updgraded to OpenZeppelin 4.9.1 and use `forceApprove` in the mentioned code now to stay compatible with this kind of token contracts.

[M-02] We're now enforcing maximum sales ending dates (366 days max). We've loosened the rule for minimum runtimes to 0, though. While a value 0 doesn't make any logic sense, it should be perfectly possible for an auctioneer to get back their auction tokens right after fail-settling the sale. We're taking care of that external requirement of a "vesting cliff" being minimal 7 days by enforcing this during the claiming call (it will use 7 days of cliff time, even though the duration config is / can be smaller)

[M-03] We'll address this issue using docs / tooltips and eventually tokenlists on the frontend side.

[L-01] We are using xWadDown everywhere.

[L-02] We implemented a pull pattern (`CrowdSale:claimResults`) that requires the beneficiary to claim the auction results in a dedicated transaction so a crowdsale can be settled in any case. If the beneficiary cannot claim their own results this doesn't affect anyone else anymore. This method is built to be callable by any address so its execution can be automated.

[L-03] Even though we can expect this method to be safe since the recipient is a Molecule wallet we fixed the mentioned issue.

[L-04] We decided to remove these methods altogether

[L-05] We changed the condition check.
