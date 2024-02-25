import { BigInt, log } from '@graphprotocol/graph-ts'
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner'
import { Balance, Token } from '../generated/schema'

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let balanceId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString()

  let balance = Balance.load(balanceId)

  if (!balance) {
    let token = Token.load(event.params.tokenContract)
    if (!token) {
      log.warning('Token {} not found for signature', [balanceId])
    }
    balance = new Balance(balanceId)
    balance.owner = event.params.signer
    balance.token = event.params.tokenContract
    balance.balance = BigInt.fromI32(0)
  }
  balance.agreementSignature = event.params.signature
  balance.save()
}
