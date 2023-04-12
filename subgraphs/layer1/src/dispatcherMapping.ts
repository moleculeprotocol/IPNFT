import { FractionalizationInitiated as FractionalizationInitiatedEvent } from '../generated/FractionalizerL2Dispatcher/FractionalizerL2Dispatcher';
import { Fractions, Ipnft } from '../generated/schema';
import { Address, dataSource } from '@graphprotocol/graph-ts';

function lookUpCollectionAddress(network: string): string {
  switch (network) {
    case 'mainnet':
      return '0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65';
    case 'goerli':
      return '0x36444254795ce6E748cf0317EEE4c4271325D92A';
    default:
      return '0x0dCcD55Fc2F116D0f0B82942CD39F4f6a5d88F65';
  }
}

export function handleFractionalizationInitiated(
  event: FractionalizationInitiatedEvent
): void {
  if (
    event.params.fractionalized.collection !=
    Address.fromHexString(lookUpCollectionAddress(dataSource.network()))
  )
    return;
  let ipnft = Ipnft.load(event.params.fractionalized.tokenId.toString());
  if (!ipnft) {
    return;
  }

  let fracInit = new Fractions(event.params.fractionId.toString());
  fracInit.txHash = event.transaction.hash;
  fracInit.initialAmount = event.params.initialAmount;
  fracInit.createdAt = event.block.timestamp;
  fracInit.ipnft = ipnft.id;
}
