import { FractionalizationInitiated as FractionalizationInitiatedEvent } from '../generated/FractionalizerL2Dispatcher/FractionalizerL2Dispatcher';
import { Fractions, Ipnft } from '../generated/schema';
import { Address, dataSource } from '@graphprotocol/graph-ts';

function shouldIndex(collection: Address): boolean {
  const network: string = dataSource.network();
  let ipnftAddress: Address;

  if (network == 'goerli') {
    ipnftAddress = Address.fromString(
      '0x36444254795ce6E748cf0317EEE4c4271325D92A'
    );
  }

  if (network == 'mainnet') {
    //todo: this could also be called homestead
    ipnftAddress = Address.fromString(
      '0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65'
    );
  }
  return collection.equals(ipnftAddress);
}

export function handleFractionalizationInitiated(
  event: FractionalizationInitiatedEvent
): void {
  if (!shouldIndex(event.params.fractionalized.collection)) {
    return;
  }

  let ipnft = Ipnft.load(event.params.fractionalized.tokenId.toString());
  if (!ipnft) {
    return;
  }

  let fractions = new Fractions(event.params.fractionId.toString());
  fractions.ipnft = ipnft.id;
  fractions.txHash = event.transaction.hash;
  fractions.originalOwner = event.params.fractionalized.originalOwner;
  fractions.initialAmount = event.params.initialAmount;
  fractions.createdAt = event.block.timestamp;
  fractions.save();
}
