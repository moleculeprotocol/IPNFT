import { BigInt } from '@graphprotocol/graph-ts'
import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'

import { ERC20Token, Token, TimelockedToken } from '../generated/schema'

export function makeTimelockedToken(
  _contract: IERC20Metadata,
  underlyingToken: ERC20Token
): TimelockedToken {
  let tlToken = TimelockedToken.load(_contract._address)

  if (!tlToken) {
    tlToken = new TimelockedToken(_contract._address)
    tlToken.id = _contract._address
    tlToken.decimals = BigInt.fromI32(_contract.decimals())
    tlToken.symbol = _contract.symbol()
    tlToken.name = _contract.name()
    tlToken.underlyingToken = underlyingToken.id
    //tlToken.underlyingToken = underlyingToken.id

    let token = Token.load(underlyingToken.id.toHexString())
    if (token) {
      tlToken.token = token.id
      token.lockedToken = tlToken.id
      token.save()
    }
    tlToken.save()
  }

  return tlToken
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
