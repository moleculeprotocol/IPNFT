import { BigInt } from '@graphprotocol/graph-ts'
import { TokensCreated as TokensCreatedEvent } from '../generated/Tokenizer/Tokenizer'

import { IPToken } from '../generated/templates'

import { IPT } from '../generated/schema'

export function handleIPTsCreated(event: TokensCreatedEvent): void {
  let reacted = new IPT(event.params.tokenContract.toHexString())

  reacted.createdAt = event.block.timestamp
  reacted.ipnft = event.params.ipnftId.toString()
  reacted.agreementCid = event.params.agreementCid
  reacted.originalOwner = event.params.emitter
  reacted.symbol = event.params.symbol
  reacted.name = event.params.name
  reacted.decimals = BigInt.fromU32(18)

  //these will be updated by the underlying IPT subgraph template
  reacted.totalIssued = BigInt.fromU32(0)
  reacted.circulatingSupply = BigInt.fromU32(0)
  IPToken.create(event.params.tokenContract)

  reacted.save()
}

// export function handleSalesActivated(event: SalesActivatedEvent): void {
//   let reacted = ReactedIpnft.load(event.params.moleculesId.toString());
//   if (!reacted) {
//     log.error('ReactedIpnft not found for id: {}', [
//       event.params.moleculesId.toString()
//     ]);
//     return;
//   }
//   reacted.paymentToken = event.params.paymentToken;
//   reacted.paidPrice = event.params.paidPrice;
//   reacted.claimedShares = BigInt.fromI32(0);
//   reacted.save();
// }
