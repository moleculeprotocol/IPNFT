import {
  BigInt,
  Bytes,
  DataSourceContext,
  log,
  ethereum
} from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'

import { Started as PlainStartedEvent } from '../generated/CrowdSale/CrowdSale'

import { handleStarted as plainHandleStarted } from './crowdSaleMapping'

import * as GenericCrowdSale from './genericCrowdSale'

import { Contribution, CrowdSale, ERC20Token, IPT } from '../generated/schema'

import { TimelockedToken as TimelockedTokenTemplate } from '../generated/templates'
import { makeERC20Token, makeTimelockedToken } from './common'

import {
  Bid as BidEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  Claimed as ClaimedEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent,
  Failed as FailedEvent,
  LockingContractCreated as LockingContractCreatedEvent,
  Settled as SettledEvent,
  Started as StartedEvent
} from '../generated/LockingCrowdSale/LockingCrowdSale'

export function handleStarted(event: StartedEvent): void {
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
      event.parameters[5]
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

  let ipt = IPT.load(event.params.sale.auctionToken.toHexString())
  if (!ipt) {
    log.error('[Crowdsale] Ipt not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ])
    return
  }

  if (!ipt.lockedToken) {
    ipt.lockedToken = event.params.lockingToken
    ipt.save()
  } else {
    let _ipt = changetype<Bytes>(ipt.lockedToken).toHexString()
    let _newToken = event.params.lockingToken.toHexString()
    if (_ipt != _newToken) {
      log.error('the locking token per IPT should be unique {} != {}', [
        _ipt,
        _newToken
      ])
    }
  }

  crowdSale.amountStaked = BigInt.fromU32(0)
  crowdSale.auctionLockingDuration = event.params.lockingDuration

  crowdSale.type = 'STAKED_LOCKING_CROWDSALE'
  crowdSale.save()
  log.info('[handleStarted] locking crowdsale {}', [crowdSale.id])
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
  context.setBytes('ipt', event.params.underlyingToken)
  context.setBytes('lockingContract', event.params.lockingContract)
  TimelockedTokenTemplate.createWithContext(
    event.params.lockingContract,
    context
  )
  const _underlyingTokenContract: IERC20Metadata = IERC20Metadata.bind(
    event.params.underlyingToken
  )
  const underlyingErc20Token: ERC20Token = makeERC20Token(
    _underlyingTokenContract
  )

  makeTimelockedToken(
    IERC20Metadata.bind(event.params.lockingContract),
    underlyingErc20Token
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
