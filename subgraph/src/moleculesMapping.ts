import { Address, BigInt, log } from '@graphprotocol/graph-ts'
import {
  Transfer as TransferEvent,
  Capped as CappedEvent
  //SharesClaimed as SharesClaimedEvent
} from '../generated/templates/Molecules/Molecules'
import { ReactedIpnft, Molecule, Ipnft } from '../generated/schema'

function createOrUpdateMolecules(
  owner: Address,
  address: string,
  value: BigInt
): void {
  let moleculesId = address + '-' + owner.toHexString()
  let molecule = Molecule.load(moleculesId)
  if (!molecule) {
    molecule = new Molecule(moleculesId)
    molecule.reactedIpnft = address
    molecule.balance = value
    molecule.owner = owner
    molecule.agreementSignature = null
  } else {
    molecule.balance = molecule.balance.plus(value)
  }
  molecule.save()
}

export function handleTransfer(event: TransferEvent): void {
  let from = event.params.from
  let to = event.params.to
  let value = event.params.value

  let reactedIpnft = ReactedIpnft.load(event.address.toHexString())
  if (!reactedIpnft) {
    log.error('ReactedIpnft Ipnft not found for id: {}', [
      event.address.toHexString()
    ])
    return
  }

  //mint
  if (from == Address.zero()) {
    createOrUpdateMolecules(to, event.address.toHexString(), value)
    reactedIpnft.totalIssued = reactedIpnft.totalIssued.plus(value)
    reactedIpnft.circulatingSupply = reactedIpnft.circulatingSupply.plus(value)
    reactedIpnft.save()

    return
  }

  //burn
  if (to == Address.zero()) {
    createOrUpdateMolecules(from, event.address.toHexString(), value.neg())
    reactedIpnft.circulatingSupply = reactedIpnft.circulatingSupply.minus(value)
    reactedIpnft.save()
    return
  }

  //transfer
  createOrUpdateMolecules(from, event.address.toHexString(), value.neg())
  createOrUpdateMolecules(to, event.address.toHexString(), value)
}

// export function handleSharesClaimed(event: SharesClaimedEvent): void {
//   let reactedIpnft = ReactedIpnft.load(event.params.moleculesId.toString());
//   if (!reactedIpnft) {
//     log.error('ReactedIpnft ipnft not found for id: {}', [
//       event.params.moleculesId.toString()
//     ]);
//     return;
//   }
//   reactedIpnft.claimedShares = reactedIpnft.claimedShares.plus(
//     event.params.amount
//   );
//   reactedIpnft.save();
// }
