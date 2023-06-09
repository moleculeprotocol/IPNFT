import { BigInt, log } from '@graphprotocol/graph-ts'
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner'
import { Molecule, ReactedIpnft } from '../generated/schema'

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let moleculesId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString()

  let molecule = Molecule.load(moleculesId)

  if (!molecule) {
    let reacted = ReactedIpnft.load(event.params.tokenContract.toHexString())
    if (!reacted) {
      log.warning('molecules {} not found for signature', [moleculesId])
    }
    molecule = new Molecule(moleculesId)
    molecule.owner = event.params.signer
    molecule.reactedIpnft = event.params.tokenContract.toHexString()
    molecule.balance = BigInt.fromI32(0)
  }
  molecule.agreementSignature = event.params.signature
  molecule.save()
}
