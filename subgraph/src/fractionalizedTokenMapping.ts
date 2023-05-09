import { Address, BigInt, log } from '@graphprotocol/graph-ts';
import {
  Transfer as TransferEvent,
  Capped as CappedEvent
  //SharesClaimed as SharesClaimedEvent
} from '../generated/templates/FractionalizedToken/FractionalizedToken';
import { Fractionalized, Fraction, Ipnft } from '../generated/schema';

function createOrUpdateFractions(
  owner: Address,
  address: string,
  value: BigInt
): void {
  let fractionId = address + '-' + owner.toHexString();
  let fraction = Fraction.load(fractionId);
  if (!fraction) {
    fraction = new Fraction(fractionId);
    fraction.fractionalizedIpfnt = address;
    fraction.balance = value;
    fraction.owner = owner;
    fraction.agreementSignature = null;
  } else {
    fraction.balance = fraction.balance.plus(value);
  }
  fraction.save();
}

export function handleTransfer(event: TransferEvent): void {
  let from = event.params.from;
  let to = event.params.to;
  let value = event.params.value;

  let fractionalized = Fractionalized.load(event.address.toHexString());
  if (!fractionalized) {
    log.error('Fractionalized Ipnft not found for id: {}', [
      event.address.toHexString()
    ]);
    return;
  }

  //mint
  if (from == Address.zero()) {
    createOrUpdateFractions(to, event.address.toHexString(), value);
    fractionalized.totalIssued = fractionalized.totalIssued.plus(value);
    fractionalized.circulatingSupply = fractionalized.circulatingSupply.plus(
      value
    );
    fractionalized.save();

    return;
  }

  //burn
  if (to == Address.zero()) {
    createOrUpdateFractions(from, event.address.toHexString(), value.neg());
    fractionalized.circulatingSupply = fractionalized.circulatingSupply.minus(
      value
    );
    fractionalized.save();
    return;
  }

  //transfer
  createOrUpdateFractions(from, event.address.toHexString(), value.neg());
  createOrUpdateFractions(to, event.address.toHexString(), value);
}

// export function handleSharesClaimed(event: SharesClaimedEvent): void {
//   let fractionalized = Fractionalized.load(event.params.fractionId.toString());
//   if (!fractionalized) {
//     log.error('Fractionalized ipnft not found for id: {}', [
//       event.params.fractionId.toString()
//     ]);
//     return;
//   }
//   fractionalized.claimedShares = fractionalized.claimedShares.plus(
//     event.params.amount
//   );
//   fractionalized.save();
// }
