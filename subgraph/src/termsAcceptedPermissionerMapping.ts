import { log } from '@graphprotocol/graph-ts';
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner';
import { Fraction } from '../generated/schema';

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let fractionId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString();

  let fraction = Fraction.load(fractionId);
  if (!fraction) {
    log.warning('fractions {} not found for signature', [fractionId]);
    return;
  }
  fraction.agreementSignature = event.params.signature;
  fraction.save();
}
