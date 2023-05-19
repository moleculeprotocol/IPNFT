import { BigInt, log } from '@graphprotocol/graph-ts';
import { TermsAccepted as TermsAcceptedEvent } from '../generated/TermsAcceptedPermissioner/TermsAcceptedPermissioner';
import { Fraction, Fractionalized } from '../generated/schema';

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let fractionId =
    event.params.tokenContract.toHexString() +
    '-' +
    event.params.signer.toHexString();

  let fraction = Fraction.load(fractionId);

  if (!fraction) {
    let fractionalized = Fractionalized.load(
      event.params.tokenContract.toHexString()
    );
    if (!fractionalized) {
      log.warning('fractions {} not found for signature', [fractionId]);
    }
    fraction = new Fraction(fractionId);
    fraction.owner = event.params.signer;
    fraction.fractionalizedIpfnt = event.params.tokenContract.toHexString();
    fraction.balance = BigInt.fromI32(0);
  }
  fraction.agreementSignature = event.params.signature;
  fraction.save();
}
