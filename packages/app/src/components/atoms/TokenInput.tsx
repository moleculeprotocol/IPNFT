import {
  useReadErc20Allowance,
  useReadErc20BalanceOf,
  useReadErc20Decimals,
  useWriteErc20Approve,
} from "@/generated/wagmi";
import { LegacyRef, forwardRef, useMemo } from "react";
import { useWatch } from "react-hook-form";
import { Address } from "viem";
import { useAccount } from "wagmi";
import { BNInput } from "./BNInput";

export const TokenInput = (props: {
  amountField: string;
  amountLabel: string;
  tokenContractAddress?: Address;
  spenderContractAddress: Address;
}) => {
  const {
    amountField,
    amountLabel,
    tokenContractAddress,
    spenderContractAddress,
  } = props;

  const { address: userAddress } = useAccount();

  const { data: decimals } = useReadErc20Decimals({
    address: tokenContractAddress,
  });
  const { data: balance } = useReadErc20BalanceOf({
    address: tokenContractAddress,
    args: [userAddress as Address],
  });
  const { data: allowance } = useReadErc20Allowance({
    address: tokenContractAddress,
    args: [userAddress as Address, spenderContractAddress],
  });
  const amountValue = useWatch({ name: amountField });

  const mustApprove = useMemo(() => {
    if (typeof allowance === "undefined") return undefined;
    return allowance < amountValue ? amountValue - allowance : 0n;
  }, [amountValue, allowance]);

  const { writeContractAsync: approve } = useWriteErc20Approve();
  console.log(mustApprove);
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-row gap-2 w-full ">
        <label className="input input-bordered flex items-center gap-2 flex-1">
          <div className="text-xs">{amountLabel}</div>
          <BNInput
            name={amountField}
            decimals={decimals}
            disabled={!tokenContractAddress}
            className="grow"
            placeholder="0x"
          />
        </label>
        {tokenContractAddress && mustApprove ? (
          <button
            className="btn btn-neutral"
            onClick={() =>
              approve({
                address: tokenContractAddress,
                args: [spenderContractAddress, mustApprove],
              })
            }
          >
            Approve
          </button>
        ) : null}
      </div>
    </div>
  );
};

TokenInput.displayName = "TokenInput";
