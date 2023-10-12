import { BigInt, log } from '@graphprotocol/graph-ts'
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
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('[handleSettled] Plain CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'SETTLED'
  crowdSale.save()
}

export function handleFailed(event: FailedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('[handleFailed] Plain CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'FAILED'
  crowdSale.save()
}

export function handleBid(event: BidEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLEBID] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }

  //   Update CrowdSale
  crowdSale.amountRaised = crowdSale.amountRaised.plus(event.params.amount)
  crowdSale.save()

  let contributionId =
    event.params.saleId.toString() + '-' + event.params.bidder.toHex()

  //   Load or Create Contribution
  let contribution = Contribution.load(contributionId)
  if (!contribution) {
    contribution = new Contribution(contributionId)
    contribution.amount = BigInt.fromI32(0)
    contribution.stakedAmount = BigInt.fromI32(0)
  }

  contribution.contributor = event.params.bidder
  contribution.createdAt = event.block.timestamp
  contribution.amount = contribution.amount.plus(event.params.amount)
  contribution.crowdSale = crowdSale.id

  contribution.save()
}

export function handleClaimed(event: ClaimedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLECLAIMED] Plain CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }

  let contributionId =
    event.params.saleId.toString() + '-' + event.params.claimer.toHex()
  //   Load  Contribution
  let contribution = Contribution.load(contributionId)

  if (contribution === null) {
    log.error(
      '[HANDLECLAIMED] No contribution found for Plain CrowdSale | user : {} | {}',
      [event.params.saleId.toString(), event.params.claimer.toHexString()]
    )
    return
  }
  contribution.claimedAt = event.block.timestamp
  contribution.claimedTx = event.transaction.hash.toHex()
  contribution.claimedTokens = event.params.claimed
  contribution.refundedTokens = event.params.refunded
  contribution.save()
}

/**
 * emitted when the auctioneer pulls / claims bidding tokens after the sale is successfully settled
 */
export function handleClaimedSuccessfulSale(
  event: ClaimedFundingGoalEvent
): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleClaimed] Plain CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
  crowdSale.claimedAt = event.block.timestamp
  crowdSale.save()
}

/**
 * emitted when the auctioneer pulls / claims back auction tokens after the sale has settled and is failed
 */
export function handleClaimedFailedSale(
  event: ClaimedAuctionTokensEvent
): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error(
      '[handleClaimedFailedSale] Plain CrowdSale not found for id: {}',
      [event.params.saleId.toString()]
    )
    return
  }
  crowdSale.claimedAt = event.block.timestamp
  crowdSale.save()
}
