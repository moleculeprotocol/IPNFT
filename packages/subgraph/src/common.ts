import { IERC20Metadata } from '../generated/CrowdSale/IERC20Metadata'

import { TimelockedToken, Token } from '../generated/schema'

export function makeTimelockedToken(
  _contract: IERC20Metadata,
  underlyingToken: Token
): TimelockedToken {

  let tlToken = TimelockedToken.load(_contract._address)

  if (!tlToken) {
    tlToken = new TimelockedToken(_contract._address)
    tlToken.id = _contract._address
    tlToken.decimals = _contract.decimals()
    tlToken.symbol = _contract.symbol()
    tlToken.name = _contract.name()
    tlToken.underlyingToken = underlyingToken.id    
    tlToken.save()
  }

  return tlToken
}

export function makeToken(_contract: IERC20Metadata): Token {
  let token = Token.load(_contract._address)

  if (!token) {
    token = new Token(_contract._address)
    token.id = _contract._address
    token.decimals = _contract.decimals()
    token.symbol = _contract.symbol()
    token.name = _contract.name()
    token.save()
  }

  return token
}
