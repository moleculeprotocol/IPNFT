import { BigInt, log } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'
import { Started as StartedEvent } from '../generated/CrowdSale/CrowdSale'

import { CrowdSale, ERC20Token, IPT } from '../generated/schema'

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
