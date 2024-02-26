import { useWriteCrowdSaleStartSale } from "@/generated/wagmi";
import { useAccount } from "wagmi";

export default function Home() {
  const { address: userAddress } = useAccount();
  const {
    data: hash,
    writeContract: startSale,
    isPending,
  } = useWriteCrowdSaleStartSale();

  return (
    <>
      <div>addr {userAddress}</div>
    </>
  );
}
