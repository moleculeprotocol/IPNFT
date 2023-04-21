import { Address, BigInt, dataSource, log } from '@graphprotocol/graph-ts';
import { Transfer as TransferEvent } from '../generated/templates/FractionalizedToken/FractionalizedToken';
import { Fractionalized, Fraction, Ipnft } from '../generated/schema';

function createOrUpdateFractions(
  owner: Address,
  fractionalizedId: string,
  value: BigInt
): void {
  let fractionId = fractionalizedId + '-' + owner.toHexString();
  let fraction = Fraction.load(fractionId);
  if (!fraction) {
    fraction = new Fraction(fractionId);
    fraction.fractionalizedIpfnt = fractionalizedId;
    fraction.balance = value;
    fraction.owner = owner;
    fraction.agreementSigned = false;
  } else {
    fraction.balance = fraction.balance.plus(value);
  }
  fraction.save();
}

export function handleTransfer(event: TransferEvent): void {
  let from = event.params.from;
  let to = event.params.to;
  let value = event.params.value;

  let fractionalizedId = dataSource
    .context()
    .getBigInt('fractionalizedId')
    .toString();
  let fractionalized = Fractionalized.load(fractionalizedId);
  if (!fractionalized) {
    log.error('Fractionalized Ipnft not found for id: {}', [fractionalizedId]);
    return;
  }

  //mint
  if (from == Address.zero()) {
    createOrUpdateFractions(to, fractionalizedId, value);
    fractionalized.totalIssued = fractionalized.totalIssued.plus(value);
    fractionalized.circulatingSupply = fractionalized.circulatingSupply.plus(
      value
    );
    fractionalized.save();

    return;
  }

  //burn
  if (to == Address.zero()) {
    createOrUpdateFractions(from, fractionalizedId, value.neg());
    fractionalized.circulatingSupply = fractionalized.circulatingSupply.minus(
      value
    );
    fractionalized.save();
    return;
  }

  //transfer
  createOrUpdateFractions(from, fractionalizedId, value.neg());
  createOrUpdateFractions(to, fractionalizedId, value);
}
