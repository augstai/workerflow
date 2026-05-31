import fs from "node:fs";
import path from "node:path";

export const CONFIG_FILE = ".workerflow.json";

export const DEFAULT_CONFIG = Object.freeze({
  schemaVersion: 1,
  agent: "codex",
  worktree: true,
  commands: {
    test: "",
    build: "",
    lint: ""
  },
  safePaths: ["app", "src", "components", "packages", "tests"],
  denyPaths: [
    ".env",
    ".env.*",
    "prisma/schema.prisma",
    "migrations",
    "secrets",
    "credentials"
  ]
});

export function projectConfigPath(cwd) {
  return path.join(cwd, CONFIG_FILE);
}

export function readProjectConfig(cwd) {
  const configPath = projectConfigPath(cwd);
  if (!fs.existsSync(configPath)) {
    return { config: null, path: null };
  }

  const raw = fs.readFileSync(configPath, "utf8");
  return {
    config: JSON.parse(raw),
    path: configPath
  };
}

export function writeProjectConfig(cwd, config) {
  const configPath = projectConfigPath(cwd);
  const normalized = {
    ...DEFAULT_CONFIG,
    ...config,
    commands: {
      ...DEFAULT_CONFIG.commands,
      ...(config.commands ?? {})
    }
  };

  fs.writeFileSync(configPath, `${JSON.stringify(normalized, null, 2)}\n`);
  return { config: normalized, path: configPath };
}
