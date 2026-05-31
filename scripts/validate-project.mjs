import fs from "node:fs";

const requiredFiles = [
  "README.md",
  "LICENSE",
  "CONTRIBUTING.md",
  "SECURITY.md",
  "CODE_OF_CONDUCT.md",
  "package.json",
  "pnpm-workspace.yaml",
  "apps/cli/package.json",
  "apps/cli/bin/workerflow.js",
  "apps/desktop/package.json",
  "apps/desktop/src/main.mjs",
  "apps/desktop/src/overlay.html",
  "apps/desktop/src/overlay.css",
  "apps/desktop/src/overlay.js",
  "apps/desktop/src/preload.cjs",
  "packages/core/package.json",
  "packages/core/src/index.js"
];

const missing = requiredFiles.filter((file) => !fs.existsSync(file));

if (missing.length) {
  console.error(`Missing required files:\n${missing.map((file) => `- ${file}`).join("\n")}`);
  process.exit(1);
}

JSON.parse(fs.readFileSync("package.json", "utf8"));
JSON.parse(fs.readFileSync("apps/cli/package.json", "utf8"));
JSON.parse(fs.readFileSync("apps/desktop/package.json", "utf8"));
JSON.parse(fs.readFileSync("packages/core/package.json", "utf8"));

console.log("Project metadata looks good.");
