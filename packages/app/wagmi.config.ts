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
          [foundryChain.id]: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853",
        },
      },
    }),
    actions(),
    react(),
  ],
});
