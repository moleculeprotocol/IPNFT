import { FractionalizationInitiated as FractionalizationInitiatedEvent } from '../generated/FractionalizerL2Dispatcher/FractionalizerL2Dispatcher';
import { Fractions, Ipnft } from '../generated/schema';
import { Address, dataSource } from '@graphprotocol/graph-ts';

function shouldIndex(collection: Address): boolean {
  const network: string = dataSource.network();
  //this only works with u32:
  switch (network) {
    case 'goerli':
      return collection.equals(
        Address.fromHexString('0x36444254795ce6E748cf0317EEE4c4271325D92A')
      );
    //todo: ideally find a way to inject the supported remote contract address via global here
    // case 'foundry': case 'localhost'
    //   return '0x0';
    case 'mainnet':
    default:
      return collection.equals(
        Address.fromHexString('0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65')
      );
  }
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
