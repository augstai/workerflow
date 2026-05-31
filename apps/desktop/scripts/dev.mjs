import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const desktopRoot = path.resolve(__dirname, "..");

const server = await createServer({
  configFile: path.join(desktopRoot, "vite.config.mjs")
});

await server.listen();
const address = server.resolvedUrls.local[0];

const electron = spawn("pnpm", ["exec", "electron", "src/main.mjs"], {
  cwd: desktopRoot,
  env: {
    ...process.env,
    WORKERFLOW_RENDERER_URL: address
  },
  stdio: "inherit"
});

electron.on("exit", async (code, signal) => {
  await server.close();
  if (signal) {
    process.exit(0);
  }
  process.exit(code ?? 0);
});

process.on("SIGINT", () => electron.kill("SIGINT"));
process.on("SIGTERM", () => electron.kill("SIGTERM"));
