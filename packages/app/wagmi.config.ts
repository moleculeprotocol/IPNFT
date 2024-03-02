import { defineConfig } from "@wagmi/cli";
import { actions, foundry } from "@wagmi/cli/plugins";
import { react } from "@wagmi/cli/plugins";
import { foundry as foundryChain } from "wagmi/chains";

export default defineConfig({
  out: "src/generated/wagmi.ts",
  plugins: [
    foundry({
      project: "../contracts",
      deployments: {
        CrowdSale: {
          [foundryChain.id]: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
        },
      },
    }),
    actions(),
    react(),
  ],
});
