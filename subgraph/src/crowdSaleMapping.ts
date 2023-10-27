import { BigInt, log } from '@graphprotocol/graph-ts'
import {
  Bid as BidEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  Claimed as ClaimedEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent,
  Failed as FailedEvent,
  Settled as SettledEvent,
  Started as StartedEvent
} from '../generated/CrowdSale/CrowdSale'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'

import { CrowdSale, IPT } from '../generated/schema'
import { makeERC20Token } from './common'
import * as GenericCrowdSale from './genericCrowdSale'

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString())

  let ipt = IPT.load(event.params.sale.auctionToken.toHexString())
  if (!ipt) {
    log.error('[Crowdsale] Ipt not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ])
    return
  }

  crowdSale.ipt = ipt.id
  crowdSale.issuer = event.params.issuer
  crowdSale.feeBp = event.params.feeBp
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
  log.info('[handleStarted] crowdsale {}', [crowdSale.id])
}

export function handleSettled(event: SettledEvent): void {
  GenericCrowdSale.handleSettled(event.params.saleId.toString())
}

export function handleFailed(event: FailedEvent): void {
  GenericCrowdSale.handleFailed(event.params.saleId.toString())
}

export function handleBid(event: BidEvent): void {
  GenericCrowdSale.handleBid(
    new GenericCrowdSale.BidEventParams(
      event.params.saleId,
      event.params.bidder,
      event.params.amount,
      event.block.timestamp
    )
  )
}

export function handleClaimed(event: ClaimedEvent): void {
  GenericCrowdSale.handleClaimed(
    new GenericCrowdSale.ClaimedEventParams(
      event.params.saleId,
      event.params.claimer,
      event.params.claimed,
      event.params.refunded,
      event.block.timestamp,
      event.transaction
    )
  )
}

/**
 * emitted when the auctioneer pulls / claims bidding tokens after the sale is successfully settled
 */
export function handleClaimedSuccessfulSale(
  event: ClaimedFundingGoalEvent
): void {
  GenericCrowdSale.handleClaimedSuccessfulSale(
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
  GenericCrowdSale.handleClaimedFailedSale(
    event.params.saleId.toString(),
    event.block.timestamp
  )
}
