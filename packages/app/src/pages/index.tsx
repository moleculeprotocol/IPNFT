import { CreatePlainCrowdsaleForm } from "@/components/crowdsales/CreatePlainCrowdsaleForm";
import { useWriteCrowdSaleStartSale } from "@/generated/wagmi";
import { useAccount } from "wagmi";

export default function Home() {
  return (
    <div className="flex flex-col ">
      <div className="prose mb-4">
        <h1>Create Plain Sale</h1>
      </div>
      <CreatePlainCrowdsaleForm />
    </div>
  );
}
