import { BigInt } from '@graphprotocol/graph-ts'
import { MoleculesCreated as MoleculesCreatedEvent } from '../generated/Synthesizer/Synthesizer'

import { Molecules } from '../generated/templates'

import { ReactedIpnft } from '../generated/schema'

export function handleMoleculesCreated(event: MoleculesCreatedEvent): void {
  let reacted = new ReactedIpnft(event.params.tokenContract.toHexString())

  reacted.createdAt = event.block.timestamp
  reacted.ipnft = event.params.ipnftId.toString()
  reacted.agreementCid = event.params.agreementCid
  reacted.originalOwner = event.params.emitter
  reacted.symbol = event.params.symbol
  reacted.name = event.params.name
  reacted.decimals = BigInt.fromU32(18)

  //these will be updated by the underlying Molecules subgraph template
  reacted.totalIssued = BigInt.fromU32(0)
  reacted.circulatingSupply = BigInt.fromU32(0)
  Molecules.create(event.params.tokenContract)

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

// export function handleTermsAccepted(event: TermsAcceptedEvent): void {
//   let moleculesId = createMoleculesId(
//     event.params.moleculesId,
//     event.params.signer
//   );
//   let molecule = Molecule.load(moleculesId);
//   if (!molecule) {
//     log.error('No molecules held by: {}', [moleculesId]);
//     return;
//   }
//   molecule.agreementSigned = true;
//   molecule.agreementSignature = event.params.signature;
//   molecule.save();
// }
