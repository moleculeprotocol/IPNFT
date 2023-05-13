import { BigInt, log } from '@graphprotocol/graph-ts';
import {
  Claimed as ClaimedEvent,
  Settled as SettledEvent,
  Started as StartedEvent,
  Bid as BidEvent
} from '../generated/StakedVestedCrowdSale/StakedVestedCrowdSale';
import { Contribution, CrowdSale, Fractionalized } from '../generated/schema';

export function handleStarted(event: StartedEvent): void {
  let crowdSale = new CrowdSale(event.params.saleId.toString());

  let fractionalized = Fractionalized.load(
    event.params.sale.auctionToken.toHexString()
  );
  if (!fractionalized) {
    log.error('Fractionalized Ipnft not found for id: {}', [
      event.params.sale.auctionToken.toHexString()
    ]);
    return;
  }

  crowdSale.fractionalizedIpnft = fractionalized.id;
  crowdSale.salesAmount = event.params.sale.salesAmount;
  crowdSale.amountRaised = BigInt.fromU32(0);
  crowdSale.amountStaked = BigInt.fromU32(0);
  crowdSale.fundingGoal = event.params.sale.fundingGoal;
  crowdSale.settled = false;
  crowdSale.issuer = event.params.issuer;
  crowdSale.createdAt = event.block.timestamp;
  crowdSale.closingTime = event.params.sale.closingTime;

  crowdSale.save();
}

export function handleBid(event: BidEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString());
  if (!crowdSale) {
    log.error('CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ]);
    return;
  }

  //   Update CrowdSale
  crowdSale.amountRaised = crowdSale.amountRaised.plus(event.params.amount);
  if (crowdSale.amountStaked !== null) {
    crowdSale.amountStaked = crowdSale.amountStaked!.plus(
      event.params.stakedAmount
    );
  }
  crowdSale.save();

  //   Create Contribution
  let contribution = new Contribution(event.transaction.hash.toHex());
  contribution.amount = event.params.amount;
  contribution.stakedAmount = event.params.stakedAmount;
  contribution.contributor = event.params.bidder;
  contribution.price = event.params.price;
  contribution.createdAt = event.block.timestamp;
  contribution.crowdSale = crowdSale.id;

  contribution.save();
}

export function handleSettled(event: SettledEvent): void {
  let crowdSale = CrowdSale.load(event.params.saleId.toString());
  if (!crowdSale) {
    log.error('CrowdSale not found for id: {}', [
      event.params.saleId.toString()
    ]);
    return;
  }
  crowdSale.settled = true;
  crowdSale.save();
}

// export function handleClaimed(event: ClaimedEvent): void {
//   let crowdSale = CrowdSale.load(event.params.saleId.toString());
//   if (!crowdSale) {
//     log.error('CrowdSale not found for id: {}', [
//       event.params.saleId.toString()
//     ]);
//     return;
//   }
// }
