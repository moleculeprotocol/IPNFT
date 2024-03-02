import { Address } from "viem";
import { add as addDate } from "date-fns/add";

//get from graphql
export enum SaleState {
  Failed = "FAILED",
  Running = "RUNNING",
  Settled = "SETTLED",
  Unknown = "UNKNOWN",
}

export enum SaleType {
  Crowdsale = "CROWDSALE",
  StakedLockingCrowdsale = "STAKED_LOCKING_CROWDSALE",
}

export const makeDefaultValues = (
  saleType: SaleType,
  beneficiary: Address | undefined
) => {
  const defaultValues = {
    biddingToken: undefined,
    beneficiary,
    fundingGoal: 0n,
    salesAmount: 0n,
    closingTime: addDate(new Date(), { days: 1 }),
  };

  if (saleType === SaleType.Crowdsale) {
    return defaultValues;
  } else {
    return {
      ...defaultValues,
      stakedToken: undefined,
      stakesVesting: undefined,
      wadFixedDaoPerBidPrice: 0,
      lockingDuration: 0,
    };
  }
};
