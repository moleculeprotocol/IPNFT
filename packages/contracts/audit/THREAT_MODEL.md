Rationale
This document should describe the potential threats that your system might face, including the assets that are at risk, the attack vectors that an attacker might use, and the potential impact of a successful attack. It should also describe the security controls that you have implemented to mitigate these threats.

# Threat model

All of the attack vectors we came up with so far are covered in the contracts' test suite. Some points that might be promising to look at:

- we support non 18-decimal bidding tokens (eg USDC) in the crowdsale and adjusted the staking price computation accordingly, but that's a potential trap
- since a sale is not settled _automatically_ at `closingTime` this might leave open a chance to game the contract logic
- we're avoiding a "double" claim simply by setting a bidder's contribution to 0 once they claimed a sale
- The crowdsale contracts are bound by linear inheritance and call their parent's base functionality. This potentially breaks the Checks/Effects/Interaction pattern because a parent contract calls a `transfer` function before a child might've updated its state
- The externally audited `ITokenVesting` contract requires a locker to deposit the amount to be vested for the beneficiary. We mark our crowd sale contracts to have `SCHEDULER` roles on the vesting contracts and ensure that they deposit as many funds per bidder as they should be able to unwrap after `cliff`. Still, we must make very sure that no one can unvest / drain more from the `ITokenVesting` contract than what they're allowed to.
- the crowdsale contracts are neither pausable nor upgradable.
