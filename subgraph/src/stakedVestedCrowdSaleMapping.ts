import {
  Address,
  BigInt,
  DataSourceContext,
  log
} from '@graphprotocol/graph-ts';
import {
  Claimed as ClaimedEvent,
  Settled as SettledEvent,
  Started as StartedEvent
} from '../generated/StakedVestedCrowdSale/StakedVestedCrowdSale';
import { CrowdSale } from '../generated/schema';

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString());

  crowdSale.auctionToken = event.params.sale.auctionToken;
  crowdSale.salesAmount = event.params.sale.salesAmount;
  crowdSale.amountRaised = BigInt.fromU32(0);
  crowdSale.amountStaked = BigInt.fromU32(0);
  crowdSale.fundingGoal = event.params.sale.fundingGoal;
  crowdSale.settled = false;
  //   crowdSale.price = event.params.price;
  crowdSale.creator = event.params.issuer;
  crowdSale.createdAt = event.block.timestamp;
  crowdSale.closingTime = event.params.sale.closingTime;
}

export function handleSettled(event: SettledEvent): void {}

export function handleClaimed(event: ClaimedEvent): void {}
