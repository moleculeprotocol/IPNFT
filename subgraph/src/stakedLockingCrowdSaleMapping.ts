import {
  BigInt,
  ethereum,
  log
} from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  Claimed as ClaimedEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent,
  ClaimedStakes as ClaimedStakesEvent,
  Failed as FailedEvent,
  Started3 as LegacyStartedEvent,
  LockingContractCreated as LockingContractCreatedEvent,
  Settled as SettledEvent,
  Staked as StakedEvent,
  Started as StartedEvent
} from '../generated/StakedLockingCrowdSale/StakedLockingCrowdSale'
import { LockingContractCreated as LockedLockingContractCreatedEvent } from '../generated/LockingCrowdSale/LockingCrowdSale'

import { Started as PlainStartedEvent } from '../generated/CrowdSale/CrowdSale'
import { Started as LockingStartedEvent } from '../generated/LockingCrowdSale/LockingCrowdSale'

import { handleStarted as plainHandleStarted } from './crowdSaleMapping'
import { handleLockingContractCreated as lockedHandleLockingContractCreated, lockingHandleStarted } from './lockingCrowdSaleMapping'

import * as GenericCrowdSale from './genericCrowdSale'

import { Contribution, CrowdSale } from '../generated/schema'

import { makeERC20Token } from './common'

/**
 * there are contracts that emit the started event without fees 
 */
export function handleStartedLegacy(event: LegacyStartedEvent): void {
  const parameters = event.parameters
  parameters[7] = new ethereum.EventParam(
    'feeBp',
    new ethereum.Value(ethereum.ValueKind.UINT, 0)
  )
  const _started = new StartedEvent(
    event.address,
    event.logIndex,
    event.transactionLogIndex,
    event.logType,
    event.block,
    event.transaction,
    parameters,
    event.receipt
  )

  return handleStarted(_started)
}

export function handleStarted(event: StartedEvent): void {
  const _plain = new PlainStartedEvent(
    event.address,
    event.logIndex,
    event.transactionLogIndex,
    event.logType,
    event.block,
    event.transaction,
    [
      event.parameters[0], // uint256 saleId
      event.parameters[1], // address issuer
      event.parameters[2], // struct  Sale
      event.parameters[7]  // uint16  feeBp
    ],
    event.receipt
  )

  plainHandleStarted(_plain)

  const _locking = new LockingStartedEvent(
    event.address,
    event.logIndex,
    event.transactionLogIndex,
    event.logType,
    event.block,
    event.transaction,
    [
      event.parameters[0], // uint256 saleId
      event.parameters[1], // address issuer
      event.parameters[2], // struct  Sale
      event.parameters[4], // TimelockedToken
      event.parameters[5], // uint256 lockingDuration
      event.parameters[7]  // uint16  feeBp
    ],
    event.receipt
  )
  lockingHandleStarted(_locking)

  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[Crowdsale] Creation failed for: {}', [
      event.params.saleId.toHexString()
    ])
    return
  }

  crowdSale.stakingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.staking.stakedToken)
  ).id
  crowdSale.vestedStakingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.staking.stakesVestingContract)
  ).id
  crowdSale.stakingDuration = event.params.stakingDuration
  crowdSale.wadFixedStakedPerBidPrice =
    event.params.staking.wadFixedStakedPerBidPrice

  crowdSale.type = 'STAKED_LOCKING_CROWDSALE'

  crowdSale.save()
  log.info('[handleStarted] staked locking crowdsale {}', [crowdSale.id])
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

export function handleLockingContractCreated(
  event: LockingContractCreatedEvent
): void {
  //xing fingers that this works!
  lockedHandleLockingContractCreated(changetype<LockedLockingContractCreatedEvent>(event))
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
