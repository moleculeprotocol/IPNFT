Rationale
This document should outline the purpose and goals of your project, as well as the functional and non-functional requirements that your code must meet. It should also describe any unique features or design decisions that might seem like vulnerabilities but are actually intentional.

# Fractionalized IPNFTs

## IPNFT as ERC1155

## The Fractionalizer

### Increasing Shares (Fraction Tokens)
The original owner of an IPNFT can tell the `Fractionalizer` to `increaseShares` any number of times and dilute existing fraction token holders. This is intended functionality for the time being, despite being a perceived vulnerability. In the future, we will use off-chain voting (Snapshot) with an oracle (UMA oSnap) to prevent non-consensus minting and dilution, but for now we are aware of this vulnerability. For now, we consider the IP-NFT original owner (multisig) a trusted entity.


## Schmackoswap as Sales Helper

### IPNFT Transferability 
Currently, the owner of an IPNFT can transfer or sell the IPNFT at their own discretion, potentially without the consent of fraction token holders. In the future we will ensure the IPNFT is locked after the `fractionalizeIpnft` function has been called to ensure all transfers and sales are governed and enforced on chain. We are aware of this vulnerability and hope to mitigate it in the future.

### IPNFT Sale Share Claiming
Currently, the owner of an IPNFT can sell the IPNFT without the use of `Schmackoswap`, and claim all of the proceeds from the sale without distributing them to fraction holders, obviously against their will. In the future we will ensure the IPNFT is locked after the `fractionalizeIpnft` function has been called to ensure all sales are governed and enforced on chain, and enforce the IPNFT holder to call `Schmackoswap` with the `Fractionalizer` as the beneficiary, ensuring fraction token holders receive their share. We are aware of this vulnerability and hope to mitigate it in the future.
