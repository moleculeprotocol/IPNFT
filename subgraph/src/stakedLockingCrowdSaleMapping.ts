import { BigInt, DataSourceContext, log } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/StakedLockingCrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  Staked as StakedEvent,
  Settled as SettledEvent,
  Started as StartedEvent,
  Failed as FailedEvent,
  Claimed as ClaimedEvent,
  lockingContractCreated as lockingContractCreatedEvent
} from '../generated/StakedLockingCrowdSale/StakedLockingCrowdSale'

import {
  Contribution,
  CrowdSale,
  ERC20Token,
  Fractionalized,
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
    token.save()
  }

  return token
}

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString())

  let fractionalized = Fractionalized.load(
    event.params.sale.auctionToken.toHexString()
  )
  if (!fractionalized) {
    log.error('Fractionalized Ipnft not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ])
    return
  }
  crowdSale.fractionalizedIpnft = fractionalized.id
  crowdSale.issuer = event.params.issuer
  crowdSale.beneficiary = event.params.sale.beneficiary
  crowdSale.closingTime = event.params.sale.closingTime
  crowdSale.createdAt = event.block.timestamp
  crowdSale.state = 'RUNNING'

  const auctionToken: ERC20Token = makeERC20Token(
    IERC20Metadata.bind(event.params.sale.auctionToken)
  )
  crowdSale.auctionToken = auctionToken.id

  crowdSale.salesAmount = event.params.sale.salesAmount
  crowdSale.lockedAuctionToken = makeTimelockedToken(
    IERC20Metadata.bind(event.params.lockingConfig.lockingContract),
    auctionToken
  ).id

  crowdSale.auctionLockingDuration = event.params.lockingConfig.duration

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
  crowdSale.stakingCliff = event.params.lockingConfig.duration
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

export function handlelockingContractCreated(
  event: lockingContractCreatedEvent
): void {
  let context = new DataSourceContext()
  context.setBytes('underlyingToken', event.params.underlyingToken)
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

//todo: implement
export function handleClaimed(event: ClaimedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('[handleClaimed] CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
}
