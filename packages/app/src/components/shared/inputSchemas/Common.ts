import { z } from "zod";

export const FIFTEEN_MINUTES = 15 * 60 * 1000;
export const CurrencyTypeEnum = z.enum(["ISO4217"]);
export const FIAT_DECIMALS = 2;

export const SchemaVersion = z
  .string()
  .min(5)
  .max(14)
  .regex(RegExp("^(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)$"))
  .describe("Semantic version number of schema that is being used");

export const AddressSchema = z
  .string()
  .regex(new RegExp(/^0x[a-fA-F0-9]{40}$/g), {
    message: "Invalid address",
  });

export const DecentralizedStorageLocation = z
  .string()
  .regex(
    new RegExp("^(ar|ipfs|http|https)\\b(://)\\w*"),
    "URL must start with ar://, ipfs://, http:// or https://"
  )
  .describe(
    "a url that resolves to the payload in a decentralized storage location"
  );

export const MonetaryValueSchema = z.object({
  value: z.number().describe(`The value of the monetary amount`),
  decimals: z.number().min(0).max(18).describe("The number of decimals"),
  currency: z
    .string()
    .min(3)
    .max(3)
    .describe("3-letter intl currency code of the monetary amount"),
  currency_type: CurrencyTypeEnum,
});
