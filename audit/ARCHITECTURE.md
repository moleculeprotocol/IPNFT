# Architecture

see [SEQUENCE.md](../SEQUENCE.md) for a sequence diagram of the following flow

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

- The Fractionalizer allows an IPNFT owner to create a derived ERC20 contract that we refer to as `FractionalizedToken`. It represents partial ownership of rights attached to an IPNFT.
- Owners of fractionalized tokens may gain access or usage rights to certain documents, secret data or may claim shares from other sources. This functionality is not immediately covered by the IPNFT contracts.
- The IPNFT owner creates an initial new `FractionalizedToken` supply by calling `fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid)`
  - this instantiates a new minimal clone of the currently defined ERC20 implementation...
  - ...and initializes it with the `Fractionalizer` contract as its owner
  - the original owner of an IPNFT can tell the `FractionalizedToken` at any time to mint an arbitrary amount of fractionalized tokens by calling its `issue` function. Token holders must be aware that they can be diluted at the discretion of the IPNFT holder. New emissions are supposed to be controlled by the governance layer that controls the multisig (contract) that still holds the IPNFT.
  - a `FractionalizedToken` can be marked as `capped` by the original owner. from there on will have a limited supply. This will be required by a `SalesShareDistributor` of that token but that's out of scope of the IPNFT protocol.
- the initial emission of `FractionalizedTokens` to other accounts will usually be supported by a crowd sale mechanism that's out of scope of the IPNFT protocol.
- Fraction holders can transfer their `FractionalizedToken` funds as they like.
- To enjoy certain benefits fraction holders must agree to a legal agreement that's stored on IPFS. The individual token's agreement content identifier is provided as string during the fractionalization transaction. Usage or enforcement of this agreement is not part of the Fractionalization protocol but rather will help enforcing legal commitments by other parts of the system.

## Permissioner

External smart contracts can utilize a `FractionalizedToken:Metadata`'s `agreementCid` to build permissioning schemes that e.g. enforce digital signatures on certain legal documents (the "FAM agreement").

- these can be EIP-191/EIP-1267 signatures over a certain message that can be created on chain and mentions the agreement cid.
- The most common case will be using a `TermsAcceptedPermissioner` contract.
- Signatures don't expire since they express the user's continuous agreement to the legal agreement.
- Legal agreements are not stored on chain but can be "signalled" on a permissioner that will emit a `TermsAccepted` event for the presented signature. Applications can index and store an user's terms acceptance status on a custom subgraph so users only have to sign it once and present the same signature several times.

## SalesShareDistributor

A future use case for fractionalized tokens is the pro rata distribution of sales proceeds to fraction holders. Once an IPNFT is sold, the proceeds are captured by the `SalesShareDistributor` contract and fraction holders can claim their share by presenting their legal agreement signature.

The claiming phase initiation differs depending on how the IPNFT has been sold:

- When the IPNFT is sold using a `Schmackoswap` listing, the sale _must_ be initialized with the respective `Fractionalizedtoken` as beneficiary
- When the listing is fulfilled, `Schmackoswap` will transfer the funds directly to the beneficiary, `FractionalizerToken`.
- _Anyone_ who wants to start the claiming phase and observes the fulfill transaction can call `afterSale` with the respective listing id.
- `Fractionalizer` will check whether the trade has been successful and transitions the fraction id into the claiming phase

- When the IPNFT is sold _externally_, the `owner` is supposed to hold the resulting funds that should to be distributed
- The `owner` calls `afterSale` using the ERC20 token that was used during the external sale and the amount the IPNFT has being sold for
- This of course implies trust that the `owner` isn't cheating (unlikely since it's a doxxed multisig)
- transitioning into the claiming phase requires the underlying token to be marked as `capped`. Otherwise the issuer could just increase the token supply after starting the claiming phase to fully dilute the claims of token holders.

When the claiming phase is initiated, any fraction holder can claim their share of the IPNFT sales funds by calling `SalesShareDistributor:claim(FractionalizedToken tokenContract, bytes memory permissions)`.

- Callers have to provide a valid legal agreement signature that's checked by a configured `Permissioner`
- All fractionalized tokens of the caller are burned during the claiming process. The caller must approve the token before being able to call `claim`
- In exchange for burning their fractionalized tokens, their _pro rata_ share of the `paymentToken` is transferred to the callers account
- This _pro rata_ share of the sales proceeds is based on the proportion of the circulating supply of fractionalized tokens owned by the claiming account

## CrowdSales

To sell `FractionalizedToken`s according to common BioDAO requirements, we're using fixed price based sales contracts. Depending on the seller's needs, there are three implementations that build upon each other:

- `CrowdSale` contains basic functionality all others depend upon
- `VestedCrowdSale` locks auction token for a defined of time as vested derivative
- `StakedVestedCrowdSale` requires contributors to lock a staking token along their contibution

The general crowdsale economical mechanics are outlined here (link). They allow overselling a sale and refund bidders the amount of tokens that weren't used according to their prorata contribution.

- a sale initiator starts a sale by locking `salesAmount` of `auctionTokens` into the CrowdSale contract and defining a `fundingGoal` of `biddingTokens` to reach the sale's goal and providing a non-extendable `closingTime`.
- a sale can be settled by _anyone_ observing the blockchain
- Any sale that's not raising `fundingGoal` bidding tokens until closing time can be `settle`d as `FAILED`. In that case all bidders can claim back all their contributions.

A `VestedCrowdSale` will create a new `TokenVesting` contract to create vesting schedules for the auction tokens that are claimed by the user. They will be able to unwrap these tokens after `cliff` duration has passed from the respective token vesting contract. Vesting contracts can also be provided and reused. If a user claims their share after the cliff has passed, the vesting schedule creation will be skipped, thus saving a significant amount of gas for the claimer

A `StakedVestedCrowdSale` will require bidders to lock `stakedToken`s into the crowd sale contract to participate. The amount of staked tokens required is determined by a fixed price (`wadFixedStakedPerBidPrice`) that's provided as fractional number with 18 decimals (wad) when the sale is initiated. We're abiding from using a price oracle here since price sources for our staked tokens might be too unreliable. Instead the sale initiator decides the price point (and will be supported by our frontend).
