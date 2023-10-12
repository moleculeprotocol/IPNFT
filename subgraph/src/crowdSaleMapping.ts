import { BigInt, log, Address, ethereum } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'
import {
  Started as StartedEvent,
  Settled as SettledEvent,
  Failed as FailedEvent,
  Bid as BidEvent,
  Claimed as ClaimedEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent
} from '../generated/CrowdSale/CrowdSale'

import { CrowdSale, ERC20Token, IPT, Contribution } from '../generated/schema'

// Helpers & Generic Handlers to handle different types of CrowdSales

export class StartedEventParams {
  saleId: BigInt
  issuer: Address
  auctionToken: Address
  biddingToken: Address
  beneficiary: Address
  fundingGoal: BigInt
  salesAmount: BigInt
  closingTime: BigInt
  permissioner: Address

  constructor(
    saleId: BigInt,
    issuer: Address,
    auctionToken: Address,
    biddingToken: Address,
    beneficiary: Address,
    fundingGoal: BigInt,
    salesAmount: BigInt,
    closingTime: BigInt,
    permissioner: Address
  ) {
    this.saleId = saleId
    this.issuer = issuer
    this.auctionToken = auctionToken
    this.biddingToken = biddingToken
    this.beneficiary = beneficiary
    this.fundingGoal = fundingGoal
    this.salesAmount = salesAmount
    this.closingTime = closingTime
    this.permissioner = permissioner
  }
}
export class BidEventParams {
  saleId: BigInt
  bidder: Address
  amount: BigInt
  blockTimestamp: BigInt

  constructor(
    saleId: BigInt,
    bidder: Address,
    amount: BigInt,
    blockTimestamp: BigInt
  ) {
    this.saleId = saleId
    this.bidder = bidder
    this.amount = amount
    this.blockTimestamp = blockTimestamp
  }
}

export class ClaimedEventParams {
  saleId: BigInt
  claimer: Address
  claimed: BigInt
  refunded: BigInt
  blockTimestamp: BigInt
  transaction: ethereum.Transaction

  constructor(
    saleId: BigInt,
    claimer: Address,
    claimed: BigInt,
    refunded: BigInt,
    blockTimestamp: BigInt,
    transaction: ethereum.Transaction
  ) {
    this.saleId = saleId
    this.claimer = claimer
    this.claimed = claimed
    this.refunded = refunded
    this.blockTimestamp = blockTimestamp
    this.transaction = transaction
  }
}

export function makeERC20Token(_contract: IERC20Metadata): ERC20Token {
  let token = ERC20Token.load(_contract._address)

  if (!token) {
    token = new ERC20Token(_contract._address)
    token.id = _contract._address
    token.decimals = BigInt.fromI32(_contract.decimals())
    token.symbol = _contract.symbol()
    token.name = _contract.name()
    token.save()
  }

  return token
}

export function handleSettledGeneric(saleId: string): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    return log.error('[handleSettled] Plain CrowdSale not found for id: {}', [
      saleId
    ])
  }
  crowdSale.state = 'SETTLED'
  crowdSale.save()
}

export function handleFailedGeneric(saleId: string): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    return log.error('[handleFailed] Plain CrowdSale not found for id: {}', [
      saleId
    ])
  }
  crowdSale.state = 'FAILED'
  crowdSale.save()
}

export function handleBidGeneric(params: BidEventParams): void {
  let crowdSale = CrowdSale.load(params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLEBID] CrowdSale not found for id: {}', [
      params.saleId.toString()
    ])
    return
  }

  //   Update CrowdSale
  crowdSale.amountRaised = crowdSale.amountRaised.plus(params.amount)
  crowdSale.save()

  let contributionId = params.saleId.toString() + '-' + params.bidder.toHex()

  //   Load or Create Contribution
  let contribution = Contribution.load(contributionId)
  if (!contribution) {
    contribution = new Contribution(contributionId)
    contribution.amount = BigInt.fromI32(0)
    contribution.stakedAmount = BigInt.fromI32(0)
  }

  contribution.contributor = params.bidder
  contribution.createdAt = params.blockTimestamp
  contribution.amount = contribution.amount.plus(params.amount)
  contribution.crowdSale = crowdSale.id

  contribution.save()
}

export function handleClaimedGeneric(params: ClaimedEventParams): void {
  let crowdSale = CrowdSale.load(params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLECLAIMED] Plain CrowdSale not found for id: {}', [
      params.saleId.toString()
    ])
    return
  }

  let contributionId = params.saleId.toString() + '-' + params.claimer.toHex()
  //   Load  Contribution
  let contribution = Contribution.load(contributionId)

  if (contribution === null) {
    log.error(
      '[HANDLECLAIMED] No contribution found for Plain CrowdSale | user : {} | {}',
      [params.saleId.toString(), params.claimer.toHexString()]
    )
    return
  }
  contribution.claimedAt = params.blockTimestamp
  contribution.claimedTx = params.transaction.hash.toHex()
  contribution.claimedTokens = params.claimed
  contribution.refundedTokens = params.refunded
  contribution.save()
}

export function handleClaimedSuccessfulSaleGeneric(
  saleId: string,
  timestamp: BigInt
): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    log.error('[handleClaimed] Plain CrowdSale not found for id: {}', [saleId])
    return
  }
  crowdSale.claimedAt = timestamp
  crowdSale.save()
}

export function handleClaimedFailedSaleGeneric(
  saleId: string,
  timestamp: BigInt
): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    log.error(
      '[handleClaimedFailedSale] Plain CrowdSale not found for id: {}',
      [saleId]
    )
    return
  }
  crowdSale.claimedAt = timestamp
  crowdSale.save()
}

// Actual Event handlers

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString())

  let ipt = IPT.load(event.params.sale.auctionToken.toHexString())
  if (!ipt) {
    log.error('[Plain Crowdsale] Ipt not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ])
    return
  }

  crowdSale.ipt = ipt.id
  crowdSale.issuer = event.params.issuer
  crowdSale.beneficiary = event.params.sale.beneficiary
  crowdSale.closingTime = event.params.sale.closingTime
  crowdSale.createdAt = event.block.timestamp
  crowdSale.state = 'RUNNING'

  crowdSale.salesAmount = event.params.sale.salesAmount

  crowdSale.biddingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.sale.biddingToken)
  ).id
  crowdSale.fundingGoal = event.params.sale.fundingGoal
  crowdSale.amountRaised = BigInt.fromU32(0)

  crowdSale.permissioner = event.params.sale.permissioner

  crowdSale.type = 'CROWDSALE'
  crowdSale.amountStaked = BigInt.fromU32(0)

  crowdSale.save()
  log.info('[handleStarted] plain crowdsale {}', [crowdSale.id])
}

export function handleSettled(event: SettledEvent): void {
  handleSettledGeneric(event.params.saleId.toString())
}

export function handleFailed(event: FailedEvent): void {
  handleFailedGeneric(event.params.saleId.toString())
}

export function handleBid(event: BidEvent): void {
  let params: BidEventParams = new BidEventParams(
    event.params.saleId,
    event.params.bidder,
    event.params.amount,
    event.block.timestamp
  )

  handleBidGeneric(params)
}

export function handleClaimed(event: ClaimedEvent): void {
  let params: ClaimedEventParams = new ClaimedEventParams(
    event.params.saleId,
    event.params.claimer,
    event.params.claimed,
    event.params.refunded,
    event.block.timestamp,
    event.transaction
  )

  handleClaimedGeneric(params)
}

/**
 * emitted when the auctioneer pulls / claims bidding tokens after the sale is successfully settled
 */
export function handleClaimedSuccessfulSale(
  event: ClaimedFundingGoalEvent
): void {
  handleClaimedSuccessfulSaleGeneric(
    event.params.saleId.toString(),
    event.block.timestamp
  )
}

/**
 * emitted when the auctioneer pulls / claims back auction tokens after the sale has settled and is failed
 */
export function handleClaimedFailedSale(
  event: ClaimedAuctionTokensEvent
): void {
  handleClaimedFailedSaleGeneric(
    event.params.saleId.toString(),
    event.block.timestamp
  )
}
