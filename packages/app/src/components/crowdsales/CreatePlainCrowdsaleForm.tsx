import {
  crowdSaleAddress,
  useReadErc20Decimals,
  useWriteCrowdSale,
  useWriteCrowdSaleStartSale,
} from "@/generated/wagmi";
import { SaleType, makeDefaultValues } from "@/lib/crowdsale";
import { FormProvider, SubmitHandler, useForm } from "react-hook-form";
import { Address, zeroAddress } from "viem";
import { useChainId, useWaitForTransactionReceipt } from "wagmi";
import { BNInput } from "../atoms/BNInput";
import { TokenInput } from "../atoms/TokenInput";
import { TokenSelector } from "../atoms/TokenSelector";
import { CreateCrowdSaleInputType } from "../shared/inputSchemas/Crowdsale";
import { useCallback, useEffect } from "react";

export const CreatePlainCrowdsaleForm = () => {
  const chainId = useChainId();

  const crowdsaleContract =
    crowdSaleAddress[chainId as keyof typeof crowdSaleAddress];

  const formProps = useForm<CreateCrowdSaleInputType>({
    defaultValues: makeDefaultValues(SaleType.Crowdsale, undefined),
  });

  const { writeContractAsync: crowdSale, data: txHash } = useWriteCrowdSale();

  const { formState, handleSubmit, control, watch, register } = formProps;

  const biddingTokenAddress = watch("biddingToken");

  const { data: decimals } = useReadErc20Decimals({
    address: biddingTokenAddress as Address,
  });

  const { data: receipt } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    console.log(receipt);
  }, [receipt]);
  const onSubmit: SubmitHandler<CreateCrowdSaleInputType> = useCallback(
    async (data) => {
      crowdSale({
        functionName: "startSale",
        args: [
          {
            auctionToken: data.auctionToken as Address,
            biddingToken: data.biddingToken as Address,
            beneficiary: data.beneficiary as Address,
            fundingGoal: data.fundingGoal,
            salesAmount: data.salesAmount,
            closingTime: BigInt(new Date(data.closingTime).getTime() / 1000),
            permissioner: zeroAddress,
          },
        ],
      });
    },
    [crowdSale]
  );

  return (
    <FormProvider {...formProps}>
      <form onSubmit={handleSubmit(onSubmit)} className="">
        <div className="flex flex-col gap-6">
          <TokenSelector tokenLabel="Auction Token" tokenField="auctionToken" />

          <TokenInput
            amountLabel="Sales Amount (auction tokens)"
            amountField="salesAmount"
            tokenContractAddress={watch("auctionToken") as Address}
            spenderContractAddress={crowdsaleContract}
          />

          <TokenSelector tokenLabel="Bidding Token" tokenField="biddingToken" />
          <label className="input input-bordered flex items-center gap-2">
            <div className="text-xs">Funding Goal</div>
            <BNInput
              name="fundingGoal"
              placeholder="0"
              decimals={decimals}
              disabled={!biddingTokenAddress}
            />
          </label>
          <label className="input input-bordered flex items-center gap-2 ">
            <div className="text-xs">Beneficiary</div>
            <input
              className="grow"
              placeholder="0x"
              {...register("beneficiary")}
            />
          </label>

          <label className="input input-bordered flex items-center gap-2">
            <div className="text-xs">Closing time</div>
            <input
              className="grow border-none"
              placeholder="0x"
              type="datetime-local"
              {...register("closingTime")}
            />
          </label>
          <button className="btn btn-secondary">Create</button>
        </div>
      </form>
    </FormProvider>
  );
};
