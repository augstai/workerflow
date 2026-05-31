import fs from "node:fs";
import path from "node:path";

export const CONFIG_FILE = ".workerflow.json";

export const DEFAULT_CONFIG = Object.freeze({
  schemaVersion: 1,
  agent: "codex",
  worktree: true,
  desktop: {
    hotkey: "Alt+Space",
    hotkeyMode: "toggle"
  },
  transcription: {
    provider: "mock",
    model: "gpt-4o-mini-transcribe",
    apiKeyEnv: "OPENAI_API_KEY",
    baseUrl: "https://api.openai.com/v1",
    azureEndpoint: "",
    azureDeployment: "",
    azureApiVersion: "2025-03-01-preview",
    azureApiKeyEnv: "AZURE_OPENAI_API_KEY",
    elevenLabsApiKeyEnv: "ELEVENLABS_API_KEY",
    elevenLabsModel: "scribe_v2"
  },
  adapters: {
    codex: {
      sandbox: "workspace-write",
      approvalPolicy: "never",
      json: false,
      timeoutMs: 1800000
    },
    claude: {
      permissionMode: "dontAsk",
      outputFormat: "json",
      timeoutMs: 1800000
    }
  },
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
  const extraAdapters = Object.fromEntries(
    Object.entries(config.adapters ?? {}).filter(([name]) => !["codex", "claude"].includes(name))
  );
  const normalized = {
    ...DEFAULT_CONFIG,
    ...config,
    desktop: {
      ...DEFAULT_CONFIG.desktop,
      ...(config.desktop ?? {})
    },
    transcription: {
      ...DEFAULT_CONFIG.transcription,
      ...(config.transcription ?? {})
    },
    adapters: {
      ...extraAdapters,
      codex: {
        ...DEFAULT_CONFIG.adapters.codex,
        ...(config.adapters?.codex ?? {})
      },
      claude: {
        ...DEFAULT_CONFIG.adapters.claude,
        ...(config.adapters?.claude ?? {})
      }
    },
    commands: {
      ...DEFAULT_CONFIG.commands,
      ...(config.commands ?? {})
    }
  };

  fs.writeFileSync(configPath, `${JSON.stringify(normalized, null, 2)}\n`);
  return { config: normalized, path: configPath };
}
