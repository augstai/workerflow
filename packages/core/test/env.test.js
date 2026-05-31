import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { loadEnvironment, parseEnvFile } from "../src/index.js";

test("parseEnvFile parses common dotenv syntax", () => {
  const entries = parseEnvFile(`
    # ignored
    WORKERFLOW_TRANSCRIPTION_PROVIDER=azure-openai
    export AZURE_OPENAI_ENDPOINT="https://example.openai.azure.com"
    AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT=voice-deploy # comment
    EMPTY=
  `);

  assert.equal(entries.WORKERFLOW_TRANSCRIPTION_PROVIDER, "azure-openai");
  assert.equal(entries.AZURE_OPENAI_ENDPOINT, "https://example.openai.azure.com");
  assert.equal(entries.AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT, "voice-deploy");
  assert.equal(entries.EMPTY, "");
});

test("loadEnvironment reads .env without replacing existing variables", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-env-"));
  const existingApiKey = process.env.AZURE_OPENAI_API_KEY;
  const existingEndpoint = process.env.AZURE_OPENAI_ENDPOINT;
  const existingEnvFile = process.env.WORKERFLOW_ENV_FILE;
  process.env.AZURE_OPENAI_API_KEY = "already-set";
  delete process.env.AZURE_OPENAI_ENDPOINT;
  delete process.env.WORKERFLOW_ENV_FILE;

  fs.writeFileSync(
    path.join(dir, ".env"),
    "AZURE_OPENAI_API_KEY=from-file\nAZURE_OPENAI_ENDPOINT=https://example.openai.azure.com\n"
  );

  try {
    const loaded = loadEnvironment({ cwd: dir, includeHome: false });
    assert.equal(loaded.length, 1);
    assert.equal(process.env.AZURE_OPENAI_API_KEY, "already-set");
    assert.equal(process.env.AZURE_OPENAI_ENDPOINT, "https://example.openai.azure.com");
  } finally {
    restoreEnv("AZURE_OPENAI_API_KEY", existingApiKey);
    restoreEnv("AZURE_OPENAI_ENDPOINT", existingEndpoint);
    restoreEnv("WORKERFLOW_ENV_FILE", existingEnvFile);
  }
});

function restoreEnv(key, value) {
  if (value === undefined) {
    delete process.env[key];
  } else {
    process.env[key] = value;
  }
}
