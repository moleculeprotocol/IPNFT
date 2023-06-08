import { BigInt, Bytes, DataSourceContext, log } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/StakedLockingCrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  Staked as StakedEvent,
  Settled as SettledEvent,
  Started as StartedEvent,
  Failed as FailedEvent,
  Claimed as ClaimedEvent,
  LockingContractCreated as LockingContractCreatedEvent
} from '../generated/StakedLockingCrowdSale/StakedLockingCrowdSale'

import {
  Contribution,
  CrowdSale,
  ERC20Token,
  ReactedIpnft,
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

    let reactedIpnft = ReactedIpnft.load(underlyingToken.id.toHexString())
    if (reactedIpnft) {
      token.reactedIpnft = reactedIpnft.id
      reactedIpnft.lockedToken = token.id
      reactedIpnft.save()
    }
    token.save()
  }

  return token
}

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString())

  let reactedIpnft = ReactedIpnft.load(
    event.params.sale.auctionToken.toHexString()
  )
  if (!reactedIpnft) {
    log.error('ReactedIpnft Ipnft not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ])
    return
  }

  if (!reactedIpnft.lockedToken) {
    reactedIpnft.lockedToken = event.params.lockingToken
    reactedIpnft.save()
  } else {
    let _reactedIpnftToken = changetype<Bytes>(
      reactedIpnft.lockedToken
    ).toHexString()
    let _newToken = event.params.lockingToken.toHexString()
    if (_reactedIpnftToken != _newToken) {
      log.error(
        'the locking token per reacted Ipnft should be unique {} != {}',
        [_reactedIpnftToken, _newToken]
      )
    }
  }

  crowdSale.reactedIpnft = reactedIpnft.id
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
  crowdSale.save()
  log.info('[handleStarted] crowdsale {}', [crowdSale.id])
}

export function handleBid(event: BidEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleBid] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }

  //   Update CrowdSale
  crowdSale.amountRaised = crowdSale.amountRaised.plus(event.params.amount)

  crowdSale.save()

  //   Create Contribution
  let contribution = new Contribution(event.transaction.hash.toHexString())
  contribution.amount = event.params.amount
  contribution.contributor = event.params.bidder
  contribution.createdAt = event.block.timestamp
  contribution.crowdSale = crowdSale.id

  contribution.save()
}

export function handleStaked(event: StakedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleStaked] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
  crowdSale.amountStaked = crowdSale.amountStaked.plus(
    event.params.stakedAmount
  )
  crowdSale.save()

  let contribution = Contribution.load(event.transaction.hash.toHexString())
  if (!contribution) {
    log.error(
      '[handleStaked] cannot associate contribution for stake handler {}',
      [event.transaction.hash.toHexString()]
    )
    return
  }
  contribution.stakedAmount = event.params.stakedAmount
  contribution.price = event.params.price
  contribution.save()
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
  context.setBytes('reactedIpnft', event.params.underlyingToken)
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

export function handleClaimed(event: ClaimedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleClaimed] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }

  if (crowdSale.contributions !== null) {
    log.error('No contributors found for CrowdSale id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
  let contributions = changetype<string[]>(crowdSale.contributions)
  for (let i = 0; i < contributions.length; i++) {
    let contribution = Contribution.load(contributions[i])
    if (!contribution) continue

    if (contribution.contributor == event.params.claimer) {
      contribution.claimedAt = event.block.timestamp
      contribution.save()
    }
  }
}
