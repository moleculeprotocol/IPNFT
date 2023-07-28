import { BigInt, Bytes, DataSourceContext, log } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/StakedLockingCrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  Staked as StakedEvent,
  Settled as SettledEvent,
  Started as StartedEvent,
  Failed as FailedEvent,
  Claimed as ClaimedEvent,
  ClaimedStakes as ClaimedStakesEvent,
  LockingContractCreated as LockingContractCreatedEvent,
  ClaimedAuctionTokens as ClaimedAuctionTokensEvent,
  ClaimedFundingGoal as ClaimedFundingGoalEvent
} from '../generated/StakedLockingCrowdSale/StakedLockingCrowdSale'

import {
  Contribution,
  CrowdSale,
  ERC20Token,
  IPT,
  TimelockedToken
} from '../generated/schema'

import { TimelockedToken as TimelockedTokenTemplate } from '../generated/templates'

function makeERC20Token(_contract: IERC20Metadata): ERC20Token {
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

function makeTimelockedToken(
  _contract: IERC20Metadata,
  underlyingToken: ERC20Token
): TimelockedToken {
  let token = TimelockedToken.load(_contract._address)

  if (!token) {
    token = new TimelockedToken(_contract._address)
    token.id = _contract._address
    token.decimals = BigInt.fromI32(_contract.decimals())
    token.symbol = _contract.symbol()
    token.name = _contract.name()
    token.underlyingToken = underlyingToken.id

    let ipt = IPT.load(underlyingToken.id.toHexString())
    if (ipt) {
      token.ipt = ipt.id
      ipt.lockedToken = token.id
      ipt.save()
    }
    token.save()
  }

  return token
}

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString())

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

  crowdSale.ipt = ipt.id
  crowdSale.issuer = event.params.issuer
  crowdSale.beneficiary = event.params.sale.beneficiary
  crowdSale.closingTime = event.params.sale.closingTime
  crowdSale.createdAt = event.block.timestamp
  crowdSale.state = 'RUNNING'

  crowdSale.salesAmount = event.params.sale.salesAmount

  crowdSale.auctionLockingDuration = event.params.lockingDuration

  crowdSale.biddingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.sale.biddingToken)
  ).id
  crowdSale.fundingGoal = event.params.sale.fundingGoal
  crowdSale.amountRaised = BigInt.fromU32(0)
  crowdSale.stakingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.staking.stakedToken)
  ).id

  crowdSale.amountStaked = BigInt.fromU32(0)
  crowdSale.vestedStakingToken = makeERC20Token(
    IERC20Metadata.bind(event.params.staking.stakesVestingContract)
  ).id
  crowdSale.stakingDuration = event.params.stakingDuration
  crowdSale.wadFixedStakedPerBidPrice =
    event.params.staking.wadFixedStakedPerBidPrice

  crowdSale.permissioner = event.params.sale.permissioner
  crowdSale.save()
  log.info('[handleStarted] crowdsale {}', [crowdSale.id])
}

export function handleSettled(event: SettledEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('[handleSettled] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'SETTLED'
  crowdSale.save()
}

export function handleFailed(event: FailedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('[handleFailed] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'FAILED'
  crowdSale.save()
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
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[HANDLECLAIMED] CrowdSale not found for id: {}', [
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
      '[HANDLECLAIMED] No contribution found for CrowdSale | user : {} | {}',
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
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleClaimed] CrowdSale not found for id: {}', [
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
    log.error('[handleClaimedFailedSale] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
  crowdSale.claimedAt = event.block.timestamp
  crowdSale.save()
}
