import { Header } from "@/components/Header";
import { Web3Provider } from "@/lib/wagmi";
import type { AppProps } from "next/app";
import "../styles/globals.css";

export default function App({ Component, pageProps }: AppProps) {
  return (
    <Web3Provider>
      <div className="container mx-auto px-4">
        <Header />
        <Component {...pageProps} />
      </div>
    </Web3Provider>
  );
}
