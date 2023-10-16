import { BigInt } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'

import { ERC20Token, IPT, TimelockedToken } from '../generated/schema'

export function makeTimelockedToken(
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
