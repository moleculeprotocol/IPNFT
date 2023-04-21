import { Address, BigInt, log } from '@graphprotocol/graph-ts';
import {
  FractionsCreated as FractionsCreatedEvent,
  SalesActivated as SalesActivatedEvent,
  TermsAccepted as TermsAcceptedEvent,
  SharesClaimed as SharesClaimedEvent
} from '../generated/Fractionalizer/Fractionalizer';
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
  frac.totalIssued = event.params.amount;
  frac.circulatingSupply = event.params.amount;
  frac.erc20address = event.params.tokenContract;
  frac.claimedShares = BigInt.fromI32(0);

  createOrUpdateFractions(
    event.params.emitter,
    event.params.fractionId,
    event.params.amount
  );

  frac.save();
}

function createOrUpdateFractions(
  owner: Address,
  fractionalizedId: BigInt,
  value: BigInt
): void {
  let fractionId = createFractionId(fractionalizedId, owner);
  let fraction = Fraction.load(fractionId);
  if (!fraction) {
    fraction = new Fraction(fractionId);
    fraction.fractionalizedIpfnt = fractionalizedId.toString();
    fraction.balance = value;
    fraction.owner = owner;
    fraction.agreementSigned = false;
  } else {
    fraction.balance = fraction.balance.plus(value);
  }
  fraction.save();
}

/**
 * Gets emitted on three different occasions:
 * 1. During a mint event (from = 0x0)
 *  1.1 Initial Fractionalization (fractions are being created)
 *      - creates a new FracIpnft (or updates the existing one, depends on which handler gets triggered first)
 *      - creates a new FracBasket entity
 *  1.2 Refractionalization (fractions are being increased)
 *      - updates the existing FracIpnft
 * 2. During a burn event (to = 0x0)
 *  2.1 User is burning fractions to claim shares (only possible if sales are activated)
 *      - updates the circulatingSupply of the FracIpnft
 *      - updates the balance of the FracBasket
 *      - updates claimedShares
 *  2.2 User is burning fractions
 *      - updates the circulatingSupply of the FracIpnft
 *      - updates the balance of the FracBasket
 *
 * 3. During a "normal" transfer event (from != 0x0 && to != 0x0)
 *      - updates the balances of the FracBaskets
 *      - sender will already have a FracBasket entity
 *      - receiver might not have a FracBasket entity
 *
 * @param event
 * @returns
 */
// export function handleTransferSingle(event: TransferSingleEvent): void {
//   // Assignments
//   let id = event.params.id;
//   let value = event.params.value;
//   let sender = event.params.from;
//   let receiver = event.params.to;

//   let frac = FracIpnft.load(id.toString());

//   if (!frac) {
//     log.error('FracIpnft not found for id: {}', [id.toString()]);
//     return;
//   }

//   // REFRACTIONALIZATION EVENT
//   // Normal Mint Event is handled by handleFractionsCreated
//   if (sender == Address.zero()) {
//     frac.totalIssued = frac.totalIssued.plus(value);
//     frac.circulatingSupply = frac.circulatingSupply.plus(value);
//     frac.save();
//     createOrUpdateFracBasket(receiver, id, value);
//     return;
//   }

//   // BURN EVENT
//   if (receiver == Address.zero()) {
//     createOrUpdateFracBasket(sender, id, value.neg());

//     frac.circulatingSupply = frac.circulatingSupply.minus(value);
//     frac.save();
//     return;
//   }

//   // NORMAL TRANSFER EVENT
//   createOrUpdateFracBasket(sender, id, value.neg());
//   createOrUpdateFracBasket(receiver, id, value);
// }

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
  fraction.save();
}
