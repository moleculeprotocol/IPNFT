import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'

// Helpers & Generic Handlers to handle different types of CrowdSales
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

import { Contribution, CrowdSale } from '../generated/schema'

export function handleSettled(saleId: string): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    return log.error('[handleSettled] CrowdSale not found for id: {}', [saleId])
  }
  crowdSale.state = 'SETTLED'
  crowdSale.save()
}

export function handleFailed(saleId: string): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    return log.error('[handleFailed] CrowdSale not found for id: {}', [saleId])
  }
  crowdSale.state = 'FAILED'
  crowdSale.save()
}

export function handleBid(params: BidEventParams): void {
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

export function handleClaimed(params: ClaimedEventParams): void {
  let crowdSale = CrowdSale.load(params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLECLAIMED] CrowdSale not found for id: {}', [
      params.saleId.toString()
    ])
    return
  }

  let contributionId = params.saleId.toString() + '-' + params.claimer.toHex()
  //   Load  Contribution
  let contribution = Contribution.load(contributionId)

  if (contribution === null) {
    log.error(
      '[HANDLECLAIMED] No contribution found for CrowdSale | user : {} | {}',
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

export function handleClaimedSuccessfulSale(
  saleId: string,
  timestamp: BigInt
): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    log.error('[handleClaimed] CrowdSale not found for id: {}', [saleId])
    return
  }
  crowdSale.claimedAt = timestamp
  crowdSale.save()
}

export function handleClaimedFailedSale(
  saleId: string,
  timestamp: BigInt
): void {
  let crowdSale = CrowdSale.load(saleId)
  if (!crowdSale) {
    log.error('[handleClaimedFailedSale] CrowdSale not found for id: {}', [
      saleId
    ])
    return
  }
  crowdSale.claimedAt = timestamp
  crowdSale.save()
}
