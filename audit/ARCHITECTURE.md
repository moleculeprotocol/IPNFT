# Architecture

see [SEQUENCE.md](../SEQUENCE.md) for a sequence diagram of the following flow

## IPNFTs

- IPNFTs are a plain ERC721 token.
- IPNFTs carry metadata that describes the underlying intellectual property and link to partly token gated legal pdf documents. So called Assignment Agreements assign certain usage rights to the holder of an IPNFT.
- IPNFTs are usually owned by multisig wallets that are controlled by an offchain governance process. The governance token that controls decisions about the IPFNT asset is external / unrelated to the IPNFT protocol.
- The IPNFT contract is deployed behind an ERC1967 UUPSProxy contract and can be upgraded at any time. It's currently owned by the Molecule Dev Team's multisig (2/3).

## Fractionalizer | FractionalizedToken

- The Fractionalizer allows an IPNFT owner to create a derived `FractionalizedToken` ERC20 contract. It represents partial ownership of rights attached to an IPNFT.
- Owners of fractionalized tokens may gain access or usage rights to certain documents, secret data or may claim shares from other sources. This functionality is not necessarily built into any IPNFT contract but can be written by 3rd parties that rely on an IPNFT's (fractional) ownership.
- The IPNFT owner creates an initial new `FractionalizedToken` supply by calling `fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid)`
  - this instantiates a new minimal clone of the currently templated `FractionalizedToken` implementation...
  - ...and initializes it with the `Fractionalizer` contract as its owner
  - the original owner of an IPNFT can tell the `FractionalizedToken` at any time to mint an arbitrary amount of fractionalized tokens by calling its `issue` function. Token holders must be aware that they can be diluted at the discretion of the IPNFT holder. New emissions are supposed to be controlled by the governance layer that controls the multisig (contract) that still holds the IPNFT.
  - a `FractionalizedToken` can be marked as `capped` by the original owner. From there on its supply is limited. This condition will be required by a `SalesShareDistributor` of that token.
- the initial emission of `FractionalizedTokens` to other accounts is out of scope of the `Fractionalizer` itself.
- Fraction holders can transfer their `FractionalizedToken`s as they like.
- To enjoy certain benefits, fraction holders might be asked to agree to a legal agreement document that can be provided during the fractionalization transaction. `FractionalizedToken`s can store them as IPFS CIDs inside their `Metadata` struct. Usage or enforcement of this agreement is not part of the `FractionalizedToken` but rather will help enforcing legal commitments by other parts (`TermsAcceptedPermissioner`) of the system.

## CrowdSales

To launch and fundraise governance shares of IPNFT projects, we've built a suite of crowdsale contracts that allow raising fixed amounts of bidding tokens in exchange for a fixed amount of fraction tokens, making this a fixed price sale. Fundraisers can bid an arbitrary amount of bidding tokens for auction tokens that are locked into the crowdsale contract for the time the sale is running. The amount of accepted bids is unrestricted, so a sale can be "oversold"; the claimable amounts for each bidder will be computed after settling the sale.

To take part in the sale, bidders are required to stake another predefined token, usually a membership token of an associated entity (a DAO) conducting the sale. When the funding goal is met after the sale's closing time, the sale can be settled which transfers funding goal of bidding tokens to the sale's beneficiary.

Each fundraiser can now claim their share of auction tokens, wrapped in a vesting token vehicle. They receive auction tokens proportionally to their final allocation, which is their bid divided by the factor the auction was oversold. They can claim their allocated vested auction tokens, their share of the overshot bid total and all of their staked tokens. Staked tokens that actively were "needed" to participate in the crowd sale are returned in a vesting wrapper at the same proportional share as the auction token.

Depending on the seller's needs, there are three implementations that build upon each other:

- `CrowdSale` contains basic functionality all others depend upon
- `LockingCrowdSale` locks auction token for a defined of time as vested derivative
- `StakedLockingCrowdSale` requires contributors to lock a staking token along their contibution

Technically speaking,

- a sale initiator starts a sale by locking `salesAmount` of `auctionTokens` into the CrowdSale contract and defining a `fundingGoal` of `biddingTokens` to reach the sale's goal and providing a non-extendable `closingTime`.
- a sale can be settled by _anyone_ observing the blockchain
- any sale that hasn't raised `fundingGoal` bidding tokens until `closingTime` can be `settle`d as `FAILED`. In that case all bidders can claim back all their contributions without any vesting restrictions.
- a `LockingCrowdSale` will create a new `TimelockedToken` contract that locks acquired auction tokens for the user in a way that they still show up in their wallet. Users will be able to unwrap these tokens after `cliff` duration has passed by calling `TimelockedToken:release(scheduleId)`. These token locking contracts can (and are supposed to be) reused after their initiation. If a user claims their share after the cliff has passed, the vested crowdsale contract will skip lock creation and send tokens directly to the claimer, thus saving a significant amount of gas.
- a `StakedLockingCrowdSale` will additionally require bidders to lock `stakedToken`s into the crowd sale contract to participate. The amount of staked tokens required is determined by a fixed price (`wadFixedStakedPerBidPrice`) that's provided as fractional number with 18 decimals (wad) when the sale is initiated. We're abiding from using a price oracle here since price sources for our staked tokens might be too unreliable. Instead the sale initiator decides the price point (and will be supported by our frontend). When claiming on a settled sale, bidders will receive the active share of staked tokens back wrapped in another vesting token contract that had to be configured when initiating the sale (it's a common vesting schedule contract used by the DAO for various purposes)

## Permissioner

Smart contracts can utilize a `FractionalizedToken:Metadata`'s `agreementCid` to build permissioning schemes that e.g. enforce digital signatures on certain legal documents (the "FAM agreement").

- these can be EIP-191/EIP-1267 signatures over a certain message that can be recreated and proven on chain and contains the agreement document's cid.
- The most common case will be to use a `TermsAcceptedPermissioner` contract.
- Signatures don't expire since they express the user's continuous agreement to the legal agreement.
- Such legal agreements are not stored in chain state. The permissioner rather emits a `TermsAccepted` event for the presented signature. Applications can index and store these events and reprovide signatures to their users so they only have to sign it once and can present the same signature for different purposes.

## Schmackoswap

- IPNFTs can be traded on the open market.
- `Schmackoswap` is an optional contract that allows selling off IPNFTs at a fixed ask price.
- The IPFNT owner can `list` an IPNFT at an `askPrice` denoted by an ERC20 `paymentToken`.
- A `listing` can optionally have a `beneficiary` address that can be different from the listing creator.
- Any buyer who'd like to fulfill the ask must be added to a whitelist, managed by the listing creator.
- A whitelisted buyer can `fulfill` a listing at any time by approving `Schmackoswap` to spend the asked amount of `paymentToken` and calling `fulfill`
- The IPNFT is atomically swapped against the payment token amount.

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
