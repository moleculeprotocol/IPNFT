import { Address, BigInt, log } from '@graphprotocol/graph-ts';
import {
  FractionsCreated as FractionsCreatedEvent,
  SalesActivated as SalesActivatedEvent,
  TransferSingle as TransferSingleEvent,
  TermsAccepted as TermsAcceptedEvent,
  SharesClaimed as SharesClaimedEvent
} from '../generated/Fractionalizer/Fractionalizer';
import { FracBasket, FracIpnft } from '../generated/schema';

function createBasketId(fracId: BigInt, owner: Address): string {
  return fracId.toString() + '-' + owner.toHexString();
}

export function handleFractionsCreated(event: FractionsCreatedEvent): void {
  let frac = new FracIpnft(event.params.fractionId.toString());

  frac.createdAt = event.block.timestamp;
  frac.circulatingSupply = event.params.amount;
  frac.totalIssued = event.params.amount;
  frac.claimedShares = BigInt.fromI32(0);
  frac.ipnftCollection = event.params.collection;
  frac.originalOwner = event.params.emitter;
  frac.ipnftId = event.params.tokenId.toString();
  frac.agreementCid = event.params.agreementCid;
  frac.symbol = event.params.symbol;

  createOrUpdateFracBasket(
    event.params.emitter,
    event.params.fractionId,
    event.params.amount
  );

  frac.save();
}

function createOrUpdateFracBasket(
  owner: Address,
  fracId: BigInt,
  value: BigInt
): void {
  let basketId = createBasketId(fracId, owner);
  let basket = FracBasket.load(basketId);
  if (!basket) {
    basket = new FracBasket(basketId);
    basket.balance = value;
    basket.owner = owner;
    basket.agreementSigned = false;
    basket.fracIpnft = fracId.toString();
  } else {
    basket.balance = basket.balance.plus(value);
  }
  basket.save();
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
export function handleTransferSingle(event: TransferSingleEvent): void {
  // Assignments
  let id = event.params.id;
  let value = event.params.value;
  let sender = event.params.from;
  let receiver = event.params.to;

  let frac = FracIpnft.load(id.toString());

  if (!frac) {
    log.error('FracIpnft not found for id: {}', [id.toString()]);
    return;
  }

  // REFRACTIONALIZATION EVENT
  // Normal Mint Event is handled by handleFractionsCreated
  if (sender == Address.zero()) {
    frac.totalIssued = frac.totalIssued.plus(value);
    frac.circulatingSupply = frac.circulatingSupply.plus(value);
    frac.save();
    createOrUpdateFracBasket(receiver, id, value);
    return;
  }

  // BURN EVENT
  if (receiver == Address.zero()) {
    createOrUpdateFracBasket(sender, id, value.neg());

    frac.circulatingSupply = frac.circulatingSupply.minus(value);
    frac.save();
    return;
  }

  // NORMAL TRANSFER EVENT
  createOrUpdateFracBasket(sender, id, value.neg());
  createOrUpdateFracBasket(receiver, id, value);
}

export function handleSharesClaimed(event: SharesClaimedEvent): void {
  let frac = FracIpnft.load(event.params.fractionId.toString());
  if (!frac) {
    log.error('FracIpnft not found for id: {}', [
      event.params.fractionId.toString()
    ]);
    return;
  }
  frac.claimedShares = frac.claimedShares.plus(event.params.amount);
  frac.save();
}

export function handleSalesActivated(event: SalesActivatedEvent): void {
  let frac = FracIpnft.load(event.params.fractionId.toString());
  if (!frac) {
    log.error('FracIpnft not found for id: {}', [
      event.params.fractionId.toString()
    ]);
    return;
  }
  frac.paymentToken = event.params.paymentToken;
  frac.paidPrice = event.params.paidPrice;
  frac.claimedShares = BigInt.fromI32(0);
  frac.save();
}

export function handleTermsAccepted(event: TermsAcceptedEvent): void {
  let basketId = createBasketId(event.params.fractionId, event.params.signer);
  let basket = FracBasket.load(basketId);
  if (!basket) {
    log.error('Basket not found for id: {}', [basketId]);
    return;
  }
  basket.agreementSigned = true;
  basket.save();
}
