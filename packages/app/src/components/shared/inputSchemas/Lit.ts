import { z } from "zod";

const ZABIElement = z.object({
  name: z.string(),
  type: z.string(),
  internalType: z.string().optional(),
});

const ZFunctionABI = z.object({
  inputs: z.array(ZABIElement),
  outputs: z.array(ZABIElement),
  name: z.string(),
  payable: z.boolean().optional(),
  stateMutability: z.enum(["view", "pure"]),
  type: z.literal("function"),
});

const BaseControlCondition = z
  .object({
    contractAddress: z.string(),
    chain: z.string(),
    returnValueTest: z.object({
      key: z.string().optional(),
      comparator: z.string(),
      value: z.string(),
    }),
  })
  .strict();

export const BasicAccessControlCondition = BaseControlCondition.extend({
  conditionType: z.literal("evmBasic"),
  standardContractType: z.enum(["ERC721", "ERC1155"]),
  method: z.string(),
  parameters: z.array(z.string()),
}).strict();

export const CustomControlCondition = BaseControlCondition.extend({
  conditionType: z.literal("evmContract"),
  functionName: z.string(),
  functionParams: z.array(z.string()),
  functionAbi: ZFunctionABI,
}).strict();

export const BooleanControlCondition = z.object({
  operator: z.enum(["or", "and"]),
});

export const AccessControlConditions = z.array(
  z.union([
    BasicAccessControlCondition,
    CustomControlCondition,
    BooleanControlCondition,
  ])
);
