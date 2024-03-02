"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ConnectKitProvider, getDefaultConfig } from "connectkit";
import { sepolia, foundry } from "wagmi/chains";
import { Config, WagmiProvider, createConfig, http } from "wagmi";
import { useEffect, useState } from "react";

export const Web3Provider = ({ children }: { children: React.ReactNode }) => {
  const [config, setConfig] = useState<Config>();

  const queryClient = new QueryClient();

  useEffect(() => {
    const _config = createConfig(
      getDefaultConfig({
        // Your dApps chains
        chains: [foundry, sepolia],
        ssr: false,
        transports: {
          // RPC URL for each chain
          [sepolia.id]: http(
            `https://eth-mainnet.g.alchemy.com/v2/${process.env.NEXT_PUBLIC_ALCHEMY_ID}`
          ),
          [foundry.id]: http(),
        },
        walletConnectProjectId: process.env
          .NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID as string,
        appName: "BioFair",

        // Optional App Info
        appDescription: "Molecule Crowdsales but public",
        // appUrl: "https://family.co", // your app's url
        // appIcon: "https://family.co/logo.png", // your app's icon, no bigger than 1024x1024px (max. 1MB)
      })
    );
    setConfig(_config);
  }, []);

  if (!config) return null;
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ConnectKitProvider>{children}</ConnectKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
};
