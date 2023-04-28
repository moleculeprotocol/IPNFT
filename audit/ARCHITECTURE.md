# Architecture

see SEQUENCE.md for a sequence diagram of the following flow

## IPNFTs

- IPNFTs are ERC1155 tokens with 1 instance each. The decision to not go with ERC721 here was a historical one.
- IPNFTs carry metadata that describes the underlying intellectual property and link to partly token gated legal pdf documents. So called Assignment Agreements assign certain usage rights to the holder of an IPNFT.
- IPNFTs are usually owned by multisig wallets that are controlled by an offchain governance process. The governance token that controls decisions about the IPFNT asset is external / unrelated to the IPNFT protocol.
- The IPNFT contract is deployed behind an ERC1967 UUPSProxy contract and can be upgraded at any time. It's currently owned by the Molecule Dev Team's multisig (2/3).

## Schmackoswap as Sales Helper

- IPNFTs can be traded on the open market.
- `Schmackoswap` is an optional contract that allows selling off IPNFTs at a fixed ask price. It works with any ERC1155 token with a supply of 1.
- The IPFNT owner can `list` an IPNFT at an `askPrice` denoted by an ERC20 `paymentToken`.
- A `listing` can optionally have a `beneficiary` address that can be different from the listing creator.
- Any buyer who'd like to fulfill the ask must be added to a whitelist, managed by the listing creator.
- A whitelisted buyer can `fulfill` a listing at any time by approving `Schmackoswap` to spend the asked amount of `paymentToken` and calling `fulfill`
- The IPNFT is atomically swapped against the payment token amount.

## The Fractionalizer

- The Fractionalizer allows an IPNFT owner to create an ERC20 contract that we refer to as `FractionalizedToken`. It represents partial ownership of rights attached to an IPNFT.
- Owners of fractionalized tokens may gain access or usage rights to certain documents, secret data or may claim shares from other sources. This functionality is not immediately covered by the IPNFT contracts.
- The IPNFT owner creates a new `FractionalizedToken` by calling `fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid) external returns (uint256 fractionId)`
  - this instantiates a new minimal clone of the currently defined ERC20 implementation...
  - ...and initializes with the `Fractionalizer` contract as its owner
  - the `Fractionalizer` contract can mint arbitrary amounts of tokens
  - the original owner of an IPNFT can tell the `Fractionalizer` at any time to mint an arbitrary amount of fractionalized tokens by calling `increaseShares`. Token holders must be aware that they can be diluted at the discretion of the IPNFT holder. New emissions are supposed to be controlled by the governance layer that controls the multisig (contract) that still holds the IPNFT.
- the initial emission of `FractionalizedTokens` to other accounts will usually be supported by an auction mechanism that's out of scope of the IPNFT protocol.
- Fraction holders can transfer their `FractionalizedToken` funds as they like.
- To enjoy certain benefits fraction holders must agree to a legal agreement that's stored on ipfs. The individual token's agreement content identifier is provided as string during the fractionalization transaction.
  - Agreements are EIP-191/EIP-1267 signatures over a certain message that can be created on chain and contains the agreement cid.
  - To execute certain functions, users must present their agreement signature. The signature doesn't expire since it expresses the user's continuous agreement to the legal agreement.
  - Legal agreements are not stored on chain but can be "signalled" by calling `acceptTerms`. The signature is presented as CALLDATA bytes and can be stored by an indexing subgraph so users only have to create it once.

A major use case for fractionalized tokens is the pro rata distribution of sales proceeds to fraction holders. Once an IPNFT is sold, the proceeds are captured by the `Fractionalizer` contract and fraction holders can claim their share by presenting their legal agreement signature. The claiming phase initiation differs from how the IPNFT has been sold:

- When the IPNFT is sold using a `Schmackoswap` listing, the sale _must_ be initialized with the `Fractionalizer` as beneficiary
- When the listing is fulfilled, `Schmackoswap` will transfer the funds directly to the beneficiary, `Fractionalizer`.
- _Anyone_ who wants to start the claiming phase and observes the fulfill transaction can call `afterSale` with the respective listing id.
- `Fractionalizer` will check whether the trade has been successful and transitions the fraction id into the claiming phase

- When the IPNFT is sold _externally_, the `owner` is supposed to hold the resulting funds that should to be distributed
- The `owner` calls `afterSale` using the ERC20 token that was used during the external sale and the amount the IPNFT has being sold for
- This of course implies trust that the `owner` isn't cheating (unlikely since it's a doxxed multisig)

When the claiming phase is initiated, any fraction holder can claim their share of the IPNFT sales funds by calling `burnToWithdrawShare`.

- Callers have to provide a valid legal agreement signature
- All fractionalized tokens of the caller are burned during the claiming process
- In exchange for burning their fractionalized tokens, their _pro rata_ share of the `paymentToken` is transferred to the callers account
- This _pro rata_ share of the sales proceeds is based on the proportion of the circulating supply of fractionalized tokens owned by the claiming account
