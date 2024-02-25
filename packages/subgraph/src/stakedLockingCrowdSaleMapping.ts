import {
  BigInt,
  Bytes,
  DataSourceContext,
  log,
  ethereum
} from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  Claimed as ClaimedEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent,
  ClaimedStakes as ClaimedStakesEvent,
  Failed as FailedEvent,
  LockingContractCreated as LockingContractCreatedEvent,
  Settled as SettledEvent,
  Staked as StakedEvent,
  Started as StartedEvent,
  Started3 as StakedLockingStartedEvent
} from '../generated/StakedLockingCrowdSale/StakedLockingCrowdSale'

import { Started as PlainStartedEvent } from '../generated/CrowdSale/CrowdSale'

import { handleStarted as plainHandleStarted } from './crowdSaleMapping'

import * as GenericCrowdSale from './genericCrowdSale'

import { Contribution, CrowdSale, Token } from '../generated/schema'

import { TimelockedToken as TimelockedTokenTemplate } from '../generated/templates'
import { makeToken, makeTimelockedToken } from './common'

export function handleStarted(event: StakedLockingStartedEvent): void {
  const _plain = new PlainStartedEvent(
    event.address,
    event.logIndex,
    event.transactionLogIndex,
    event.logType,
    event.block,
    event.transaction,
    [
      event.parameters[0],
      event.parameters[1],
      event.parameters[2],
      event.parameters[7]
    ],
    event.receipt
  )

  plainHandleStarted(_plain)

  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[Crowdsale] Creation failed for: {}', [
      event.params.saleId.toHexString()
    ])
    return
  }

  let token = Token.load(event.params.sale.auctionToken)
  if (!token) {
    log.error("[LSCS:handleStarted] Token wasnt created by plain handler: {}", [event.params.saleId.toHexString()])
    return
  }

  // if (token.lockedToken) {
  //   if (token.lockedToken._id != event.params.lockingToken) {
  //     log.error('the locking token per Token should be unique {} != {}', [
  //       token.lockedToken.toHexString(),
  //       event.params.lockingToken.toHexString()
  //     ])
  //   } 
  // } else {
  //   token.lockedToken = event.params.lockingToken
  // }

  crowdSale.amountStaked = BigInt.fromU32(0)
  crowdSale.auctionLockingDuration = event.params.lockingDuration

  crowdSale.stakingToken = makeToken(
    IERC20Metadata.bind(event.params.staking.stakedToken)
  ).id
  crowdSale.vestedStakingToken = makeToken(
    IERC20Metadata.bind(event.params.staking.stakesVestingContract)
  ).id
  crowdSale.stakingDuration = event.params.stakingDuration
  crowdSale.wadFixedStakedPerBidPrice =
    event.params.staking.wadFixedStakedPerBidPrice

  crowdSale.type = 'STAKED_LOCKING_CROWDSALE'

  token.save()
  crowdSale.save()
  log.info('[handleStarted] staked locking crowdsale {}', [crowdSale.id])
}

export function handleSettled(event: SettledEvent): void {
  GenericCrowdSale.handleSettled(event.params.saleId.toString())
}

export function handleFailed(event: FailedEvent): void {
  GenericCrowdSale.handleFailed(event.params.saleId.toString())
}

export function handleLockingContractCreated(
  event: LockingContractCreatedEvent
): void {
  let context = new DataSourceContext()
  context.setBytes('token', event.params.underlyingToken)
  context.setBytes('lockingContract', event.params.lockingContract)
  TimelockedTokenTemplate.createWithContext(
    event.params.lockingContract,
    context
  )

  const underlyingToken: Token = makeToken(
    IERC20Metadata.bind(
      event.params.underlyingToken
    )
  )

  makeTimelockedToken(
    IERC20Metadata.bind(event.params.lockingContract),
    underlyingToken
  )
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

export function handleStaked(event: StakedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())

  if (!crowdSale) {
    log.error('[HANDLESTAKED] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }

  crowdSale.amountStaked = crowdSale.amountStaked.plus(
    event.params.stakedAmount
  )
  crowdSale.save()

  let contributionId =
    event.params.saleId.toString() + '-' + event.params.bidder.toHex()

  //   Load or Create Contribution
  let contribution = Contribution.load(contributionId)
  if (!contribution) {
    //this should never happen, actually
    log.warning(
      '[HANDLESTAKED] No contribution found for CrowdSale | user : {} | {}',
      [event.params.saleId.toString(), event.params.bidder.toHexString()]
    )

    contribution = new Contribution(contributionId)
    contribution.amount = BigInt.fromI32(0)
    contribution.stakedAmount = BigInt.fromI32(0)
    contribution.crowdSale = crowdSale.id
    contribution.createdAt = event.block.timestamp
  }

  contribution.price = event.params.price

  contribution.stakedAmount = contribution.stakedAmount.plus(
    event.params.stakedAmount
  )

  contribution.save()
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

export function handleClaimedStakes(event: ClaimedStakesEvent): void {
  let contributionId =
    event.params.saleId.toString() + '-' + event.params.claimer.toHex()
  // Load Contribution
  let contribution = Contribution.load(contributionId)
  if (contribution === null) {
    log.error(
      '[HANDLECLAIMED] No contribution found for CrowdSale | user : {} | {}',
      [event.params.saleId.toString(), event.params.claimer.toHexString()]
    )
    return
  }
  contribution.claimedStakes = event.params.stakesClaimed
  contribution.refundedStakes = event.params.stakesRefunded
  contribution.save()
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
