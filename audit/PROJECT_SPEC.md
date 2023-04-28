# Project Spec

## IPNFT as ERC1155

IPNFTs are modeled as ERC1155 tokens with a supply of 1 where they simply could be an ERC721. This has historical reasons.

## Fractionalizer

### Increasing Shares (Fraction Tokens)

The original owner of an IPNFT can tell the `Fractionalizer` to `increaseShares` any number of times and dilute existing fraction token holders. This is intended functionality for the time being, despite being a perceived vulnerability. In the future, we will use off-chain voting (Snapshot) with an oracle (UMA oSnap) to prevent non-consensus minting and dilution, but for now we are aware of and fine with this. For now, we consider the IP-NFT original owner (multisig) a trusted entity.

### Unique Fractionalization identifiers

An IPNFT can be fractionalized several times but only once per "original owner". That's not a perfect solution and doesn't cover the constructed case that someone fractionalizes, sells to someone else, who fractionalizes it again, and sells it back to the first owner - this one would not be able to fractionalize it another time.

### ERC20 fraction tokens are not (will never be) upgradeable

ERC20 contracts are spawned when the IPNFT is fractionalized. Their bytecode is fixed and unproxied. Their template code is stored on the Fractionalizer contract so we can update the template itself but that only affects token contracts deployed on new fractionalization actions. The old tokens will stay at the code level they have been created with.

## Schmackoswap as Sales Helper

### IPNFT Transferability

Currently, the owner of an IPNFT can transfer or sell the IPNFT at their own discretion, potentially without the consent of fraction token holders. In the future we will ensure the IPNFT is locked during the `fractionalizeIpnft` function to ensure all IPNFT transfers and sales can be governed and enforced on chain. We are aware of this trust tradeoff and hope to mitigate it in the future.

### IPNFT Sale Share Claiming

Currently, the owner of an IPNFT can sell the IPNFT without the use of `Schmackoswap`, and claim all of the proceeds from the sale without distributing them to fraction holders, obviously against their will. In the future we will ensure the IPNFT is locked after the `fractionalizeIpnft` function has been called to ensure all sales are governed and enforced on chain, and enforce the IPNFT holder to call `Schmackoswap` with the `Fractionalizer` as the beneficiary, ensuring fraction token holders receive their share. We are aware of this vulnerability and hope to mitigate it in the future.
