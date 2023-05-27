import { BigInt, log } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/StakedVestedCrowdSale/IERC20Metadata'
import {
  Bid as BidEvent,
  Staked as StakedEvent,
  Settled as SettledEvent,
  Started as StartedEvent,
  Failed as FailedEvent,
  Claimed as ClaimedEvent
} from '../generated/StakedVestedCrowdSale/StakedVestedCrowdSale'

import {
  Contribution,
  CrowdSale,
  ERC20Token,
  Fractionalized
} from '../generated/schema'

function makeERC20Token(_contract: IERC20Metadata): ERC20Token {
  let token = ERC20Token.load(_contract._address)

  if (!token) {
    token = new ERC20Token(_contract._address)
    token.id = _contract._address
    token.decimals = BigInt.fromI32(_contract.decimals())
    token.symbol = _contract.symbol()
    token.name = _contract.name()
  }

  token.save()
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

  crowdSale.auctionToken = makeERC20Token(
    IERC20Metadata.bind(event.params.sale.auctionToken)
  ).id
  crowdSale.salesAmount = event.params.sale.salesAmount
  crowdSale.vestedAuctionToken = makeERC20Token(
    IERC20Metadata.bind(event.params.vesting.vestingContract)
  ).id

  crowdSale.auctionCliff = event.params.vesting.cliff

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
  crowdSale.stakingCliff = event.params.vesting.cliff
  crowdSale.wadFixedStakedPerBidPrice =
    event.params.staking.wadFixedStakedPerBidPrice
  crowdSale.save()
}

export function handleBid(event: BidEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('CrowdSale not found for id: {}', [
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
    log.error('CrowdSale not found for id: {}', [
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
    log.error('cannot associate contribution for stake handler {}', [
      event.transaction.hash.toHexString()
    ])
    return
  }
  contribution.stakedAmount = event.params.stakedAmount
  contribution.price = event.params.price
  contribution.save()
}

export function handleSettled(event: SettledEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'SETTLED'
  crowdSale.save()
}

export function handleFailed(event: FailedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    return log.error('CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
  }
  crowdSale.state = 'FAILED'
  crowdSale.save()
}

export function handleClaimed(event: ClaimedEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString())
  if (!crowdSale) {
    log.error('CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ])
    return
  }
}
