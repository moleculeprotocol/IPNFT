import {
  useReadErc20BalanceOf,
  useReadErc20Decimals,
  useReadErc20Symbol,
} from "@/generated/wagmi";
import { useController, useFormContext } from "react-hook-form";
import { Address, formatUnits } from "viem";
import { useAccount } from "wagmi";

export const TokenSelector = (props: {
  tokenField: string;
  tokenLabel: string;
}) => {
  const { tokenField, tokenLabel } = props;
  const { address: userAddress } = useAccount();

  const { control } = useFormContext();
  const { field } = useController({ name: tokenField, control });

  const { data: symbol } = useReadErc20Symbol({
    address: field.value as Address,
  });
  const { data: decimals } = useReadErc20Decimals({
    address: field.value as Address,
  });

  const { data: balance } = useReadErc20BalanceOf({
    address: field.value as Address,
    args: [userAddress as Address],
  });

  return (
    <div className="flex flex-col gap-1">
      <div className="flex w-full gap-2 items-center">
        <label className="input input-bordered flex items-center gap-2 flex-1 ">
          <div className="label text-xs">{tokenLabel}</div>
          <input {...field} className="grow" placeholder="0x" />
          <span className="label-text-alt">{symbol}</span>
        </label>
      </div>
      <div className="text-sm">
        Balance: {balance ? formatUnits(balance, decimals || 18) : null}
      </div>
    </div>
  );
};

TokenSelector.displayName = "TokenSelector";
