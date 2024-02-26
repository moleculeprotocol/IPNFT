import { defineConfig } from "@wagmi/cli";
import { actions, foundry } from "@wagmi/cli/plugins";
import { react } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "src/generated/wagmi.ts",
  //contracts: [],
  plugins: [
    foundry({
      project: "../contracts",
    }),
    actions(),
    react(),
  ],
});
