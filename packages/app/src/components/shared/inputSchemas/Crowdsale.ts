import { z } from "zod";
import { FIFTEEN_MINUTES, AddressSchema } from "./Common";

export const CrowdSaleInputSchema = z.object({ biddingAmount: z.bigint() });

export const CreateCrowdSaleInputSchema = z.object({
  auctionToken: AddressSchema,
  biddingToken: AddressSchema,
  beneficiary: AddressSchema,
  fundingGoal: z.bigint(),
  salesAmount: z.bigint(),
  closingTime: z.date().min(new Date(Date.now() + FIFTEEN_MINUTES)),
});

export type CrowdSaleInputType = z.input<typeof CrowdSaleInputSchema>;
export type CreateCrowdSaleInputType = z.input<
  typeof CreateCrowdSaleInputSchema
>;

// Staked Locked CrowdSale
export const StakedLockedCrowdSaleInputSchema = CrowdSaleInputSchema.extend({
  stakingAmount: z.bigint(),
});

export const CreateStakedLockedCrowdSaleInputSchema =
  CreateCrowdSaleInputSchema.extend({
    lockingContract: AddressSchema.or(z.undefined()),
    stakedToken: AddressSchema,
    stakesVesting: AddressSchema,
    wadFixedDaoPerBidPrice: z.number().gte(0),
    lockingDuration: z.number(),
  });

export type StakedLockedCrowdSaleInputType = z.input<
  typeof StakedLockedCrowdSaleInputSchema
>;
export type CreateStakedLockedCrowdSaleInputType = z.input<
  typeof CreateStakedLockedCrowdSaleInputSchema
>;
