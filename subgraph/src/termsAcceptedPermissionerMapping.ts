import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner';
import { Fraction } from '../generated/schema';

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let fraction = Fraction.load(event.params.tokenContract.toHexString());
  if (!fraction) {
    return;
  }
  fraction.agreementSignature = event.params.signature;
  fraction.save();
}
