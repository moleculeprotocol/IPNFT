import { BigInt } from '@graphprotocol/graph-ts'
import { TokensCreated as TokensCreatedEvent } from '../generated/Tokenizer/Tokenizer'

import { IPToken } from '../generated/templates'

import { IPT } from '../generated/schema'

export function handleIPTsCreated(event: TokensCreatedEvent): void {
  let ipt = new IPT(event.params.tokenContract.toHexString())

  ipt.createdAt = event.block.timestamp
  ipt.ipnft = event.params.ipnftId.toString()
  ipt.agreementCid = event.params.agreementCid
  ipt.originalOwner = event.params.emitter
  ipt.symbol = event.params.symbol
  ipt.name = event.params.name
  ipt.decimals = BigInt.fromU32(18)

  //these will be updated by the underlying IPT subgraph template
  ipt.totalIssued = BigInt.fromU32(0)
  ipt.circulatingSupply = BigInt.fromU32(0)
  IPToken.create(event.params.tokenContract)

  ipt.save()
}
