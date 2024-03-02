import { formatUnits, parseUnits } from "viem";

export const bnTransform = {
  toBn: (val: string, decimals = 18) => (val ? parseUnits(val, decimals) : 0n),
  toString: (val: bigint, decimals = 18) => formatUnits(val, decimals),
};
