import { FractionalizationInitiated as FractionalizationInitiatedEvent } from '../generated/FractionalizerL2Dispatcher/FractionalizerL2Dispatcher';
import { FracInit, Ipnft } from '../generated/schema';

export function handleFractionalizationInitiated(
  event: FractionalizationInitiatedEvent
): void {
  let ipnft = Ipnft.load(event.params.tokenId.toString());
  if (!ipnft) {
    return;
  }

  let fracInit = new FracInit(event.params.tokenId.toString());
  fracInit.collection = event.params.collection;
  fracInit.txHash = event.transaction.hash;
  fracInit.emitter = event.params.initiator;
  fracInit.initialAmount = event.params.initialAmount;
  fracInit.createdAt = event.block.timestamp;
  fracInit.ipnft = ipnft.id;
}
