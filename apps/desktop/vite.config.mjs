import path from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: path.join(__dirname, "renderer"),
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.join(__dirname, "renderer/src")
    }
  },
  build: {
    outDir: path.join(__dirname, "dist/renderer"),
    emptyOutDir: true
  },
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: false
  }
});
