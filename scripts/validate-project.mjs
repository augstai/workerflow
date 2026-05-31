import fs from "node:fs";
import { execFileSync } from "node:child_process";

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
  "apps/desktop/src/preload.cjs",
  "apps/desktop/renderer/index.html",
  "apps/desktop/renderer/src/main.tsx",
  "apps/desktop/renderer/src/styles.css",
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

const secretFindings = scanTrackedFilesForSecrets();

if (secretFindings.length) {
  console.error("Potential secrets found in tracked files:");
  console.error(secretFindings.map((finding) => `- ${finding}`).join("\n"));
  process.exit(1);
}

console.log("Project metadata and secret guard look good.");

function scanTrackedFilesForSecrets() {
  const files = execFileSync("git", ["ls-files"], { encoding: "utf8" }).split("\n").filter(Boolean);
  const findings = [];

  for (const file of files) {
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) continue;

    const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
    lines.forEach((line, index) => {
      if (/sk-(?:proj-)?[A-Za-z0-9_-]{20,}/.test(line)) {
        findings.push(`${file}:${index + 1}: OpenAI-style API key`);
      }

      const assignment = line.match(/^\s*(?:export\s+)?([A-Z0-9_]*API_KEY)\s*=\s*['"]?([^'"\s#]*)/);
      if (!assignment) return;

      const [, key, value] = assignment;
      if (!isSensitiveEnvKey(key) || isAllowedPlaceholder(value)) return;

      findings.push(`${file}:${index + 1}: ${key} has a non-placeholder value`);
    });
  }

  return findings;
}

function isSensitiveEnvKey(key) {
  return [
    "ANTHROPIC_API_KEY",
    "AZURE_OPENAI_API_KEY",
    "ELEVENLABS_API_KEY",
    "OPENAI_API_KEY"
  ].includes(key);
}

function isAllowedPlaceholder(value) {
  return (
    value === "" ||
    value === "already-set" ||
    value === "from-file" ||
    value === "<your-api-key>" ||
    value.startsWith("YOUR_")
  );
}
