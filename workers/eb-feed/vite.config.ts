import { cloudflare } from "@cloudflare/vite-plugin";
import { defineConfig } from "vite-plus";

export default defineConfig({
  // The Workers plugin rejects Vitest's Node environment; unit tests run plain Node.
  plugins: process.env.VITEST ? [] : [cloudflare()],
  lint: {
    ignorePatterns: ["worker-configuration.d.ts"],
    options: { typeAware: true, typeCheck: true },
  },
  fmt: { ignorePatterns: ["worker-configuration.d.ts"] },
});
