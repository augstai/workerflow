import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { DEFAULT_CONFIG, transcribeAudioFile } from "../src/index.js";

test("mock transcription derives command text from file name", async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "fix-auth-test.webm");
  fs.writeFileSync(filePath, "mock");

  const result = await transcribeAudioFile({
    filePath,
    config: DEFAULT_CONFIG
  });

  assert.equal(result.cleaned, "Fix auth test");
});

test("azure transcription validates endpoint config before network", async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.webm");
  fs.writeFileSync(filePath, "mock");

  await assert.rejects(
    transcribeAudioFile({
      filePath,
      config: {
        ...DEFAULT_CONFIG,
        transcription: {
          ...DEFAULT_CONFIG.transcription,
          provider: "azure-openai"
        }
      }
    }),
    /Missing transcription\.azureEndpoint/
  );
});

test("azure transcription can read endpoint and deployment from env", async () => {
  const previousProvider = process.env.WORKERFLOW_TRANSCRIPTION_PROVIDER;
  const previousEndpoint = process.env.AZURE_OPENAI_ENDPOINT;
  const previousDeployment = process.env.AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT;
  const previousKey = process.env.AZURE_OPENAI_API_KEY;

  process.env.WORKERFLOW_TRANSCRIPTION_PROVIDER = "azure-openai";
  process.env.AZURE_OPENAI_ENDPOINT = "https://example.openai.azure.com";
  process.env.AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT = "voice-deploy";
  delete process.env.AZURE_OPENAI_API_KEY;

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.webm");
  fs.writeFileSync(filePath, "mock");

  try {
    await assert.rejects(
      transcribeAudioFile({
        filePath,
        config: DEFAULT_CONFIG
      }),
      /Missing AZURE_OPENAI_API_KEY/
    );
  } finally {
    restoreEnv("WORKERFLOW_TRANSCRIPTION_PROVIDER", previousProvider);
    restoreEnv("AZURE_OPENAI_ENDPOINT", previousEndpoint);
    restoreEnv("AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT", previousDeployment);
    restoreEnv("AZURE_OPENAI_API_KEY", previousKey);
  }
});

function restoreEnv(key, value) {
  if (value === undefined) {
    delete process.env[key];
  } else {
    process.env[key] = value;
  }
}
