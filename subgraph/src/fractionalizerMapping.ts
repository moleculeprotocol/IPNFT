import {
  Address,
  BigInt,
  DataSourceContext,
  log
} from '@graphprotocol/graph-ts';
import {
  FractionsCreated as FractionsCreatedEvent,
  SalesActivated as SalesActivatedEvent,
  TermsAccepted as TermsAcceptedEvent,
  SharesClaimed as SharesClaimedEvent
} from '../generated/Fractionalizer/Fractionalizer';

import { FractionalizedToken } from '../generated/templates';

import { Fractionalized, Fraction, Ipnft } from '../generated/schema';

function createFractionId(fracId: BigInt, owner: Address): string {
  return fracId.toString() + '-' + owner.toHexString();
}

export function handleFractionsCreated(event: FractionsCreatedEvent): void {
  let frac = new Fractionalized(event.params.fractionId.toString());

  frac.ipnft = event.params.tokenId.toString();
  frac.createdAt = event.block.timestamp;
  frac.agreementCid = event.params.agreementCid;
  frac.originalOwner = event.params.emitter;
  frac.erc20address = event.params.tokenContract;
  //these will be updated by the underlying token graph
  frac.totalIssued = BigInt.fromU32(0);
  frac.circulatingSupply = BigInt.fromU32(0);
  frac.claimedShares = BigInt.fromU32(0);
  frac.symbol = event.params.symbol;
  frac.tokenName = event.params.name;
  let context = new DataSourceContext();
  context.setBigInt('fractionalizedId', event.params.fractionId);
  FractionalizedToken.createWithContext(event.params.tokenContract, context);

  frac.save();
}

export function handleSalesActivated(event: SalesActivatedEvent): void {
  let fractionalized = Fractionalized.load(event.params.fractionId.toString());
  if (!fractionalized) {
    log.error('FracIpnft not found for id: {}', [
      event.params.fractionId.toString()
    ]);
    return;
  }
  fractionalized.paymentToken = event.params.paymentToken;
  fractionalized.paidPrice = event.params.paidPrice;
  fractionalized.claimedShares = BigInt.fromI32(0);
  fractionalized.save();
}

export function handleSharesClaimed(event: SharesClaimedEvent): void {
  let fractionalized = Fractionalized.load(event.params.fractionId.toString());
  if (!fractionalized) {
    log.error('Fractionalized ipnft not found for id: {}', [
      event.params.fractionId.toString()
    ]);
    return;
  }
  fractionalized.claimedShares = fractionalized.claimedShares.plus(
    event.params.amount
  );
  fractionalized.save();
}

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let fractionId = createFractionId(
    event.params.fractionId,
    event.params.signer
  );
  let fraction = Fraction.load(fractionId);
  if (!fraction) {
    log.error('No fractions held by: {}', [fractionId]);
    return;
  }
  fraction.agreementSigned = true;
  fraction.agreementSignature = event.params.signature;
  fraction.save();
}
