import { BigInt, log } from '@graphprotocol/graph-ts'
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner'
import { Balance, Token } from '../generated/schema'

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let balanceId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString()

  let iptBalance = Balance.load(balanceId)

  if (!iptBalance) {
    let reacted = Token.load(event.params.tokenContract.toHexString())
    if (!reacted) {
      log.warning('Token {} not found for signature', [balanceId])
    }
    iptBalance = new Balance(balanceId)
    iptBalance.owner = event.params.signer
    iptBalance.token = event.params.tokenContract.toHexString()
    iptBalance.balance = BigInt.fromI32(0)
  }
  iptBalance.agreementSignature = event.params.signature
  iptBalance.save()
}
