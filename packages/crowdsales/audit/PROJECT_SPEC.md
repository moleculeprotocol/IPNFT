# Project Spec

## Synthesizer

### Increasing Shares (Molecules)

The original owner of an IPNFT can tell the `Molecules` to `issue` any number of times and dilute existing molecule holders as long as the `Molecules` is not marked as `capped`. This is intended functionality for the time being, despite being a perceived vulnerability. In the future, we will use off-chain voting (Snapshot) with an oracle (UMA oSnap) to prevent non-consensus minting and dilution, but for now we are aware of and fine with this. For now, we consider the IP-NFT original owner (multisig) a trusted entity.

### Unique Synthesis identifiers

An IPNFT can be synthesized several times but only once per "original owner". That's not a perfect solution and doesn't cover the constructed case that someone synthesizes, sells to someone else, who synthesizes it again, and sells it back to the first owner.

### ERC20 Molecules are not (will never be) upgradeable

ERC20 contracts are spawned when the IPNFT is synthesized. Their bytecode is fixed and unproxied. Their template code is stored on the Synthesizer contract so we can update the template itself but that only affects token contracts deployed on new synthesis actions. The old tokens will stay at the code level they have been created with.

## Crowdsale

### fixed stake pricing

The `StakedLockingCrowdSale` will require bidders to send along the same _value_ of staked tokens as they provide bidding tokens. This value must be determined by a price ratio which cannot be reliably / generally determined on chain for tokens with low trading volume. While we have built our own oracle proxy contract (BioPriceFeed) that might be extended in the future to support a fluent staking behaviour (the bidding vs DAO token price is likely varying during the sale). At the moment the sales initiator provides a fixed staked token price ratio when starting the sale.

### bidding token support

Besides the bidding token all involved ERC20 tokens must be calculated with 18 decimals. Particularly to also support USDC as bidding token, the bidding token can have arbitrary decimals. We're not supporting native ETH as any token.

### Dust

We're using solmate's FP math library to calculate refund / vesting / return ratios. Since the math precision is limited, many computations will leave some dust inside the crowdsale contract. This is covered by our tests and dust amounts might slightly differ depending on the bidding token's decimals.

## Schmackoswap as Sales Helper

### IPNFT Transferability

Currently, the owner of an IPNFT can transfer or sell the IPNFT at their own discretion, potentially without the consent of molecule holders. In the future we will ensure the IPNFT is locked during the `synthesizeIpnft` function to ensure all IPNFT transfers and sales can be governed and enforced on chain. This trust tradeoff can be responded to by checking that the IPNFT is held by a sufficiently trusted multisig at the moment.

### IPNFT Sale Share Claiming

Currently, the owner of an IPNFT can sell the IPNFT without the use of `Schmackoswap`, and claim all of the proceeds from the sale without distributing them to molecule holders, obviously against their will. In the future we will ensure the IPNFT is locked after the `synthesizeIpnft` function has been called to ensure all sales are governed and enforced on chain, and enforce the IPNFT holder to call `Schmackoswap` with the `Synthesizer` as the beneficiary, ensuring molecule holders receive their share.
