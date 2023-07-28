import { BigInt, log } from '@graphprotocol/graph-ts'
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner'
import { IPTBalance, IPT } from '../generated/schema'

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let balanceId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString()

  let iptBalance = IPTBalance.load(balanceId)

  if (!iptBalance) {
    let reacted = IPT.load(event.params.tokenContract.toHexString())
    if (!reacted) {
      log.warning('IPT {} not found for signature', [balanceId])
    }
    iptBalance = new IPTBalance(balanceId)
    iptBalance.owner = event.params.signer
    iptBalance.ipt = event.params.tokenContract.toHexString()
    iptBalance.balance = BigInt.fromI32(0)
  }
  iptBalance.agreementSignature = event.params.signature
  iptBalance.save()
}
