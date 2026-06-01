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

test("provider transcription rejects prompt echo on empty audio", async () => {
  const previousFetch = globalThis.fetch;
  const previousKey = process.env.OPENAI_API_KEY;
  const prompt = "Developer voice command for a coding-agent task.";

  process.env.OPENAI_API_KEY = "test-key";
  globalThis.fetch = async () => Response.json({ text: prompt });

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.webm");
  fs.writeFileSync(filePath, "mock");

  try {
    await assert.rejects(
      transcribeAudioFile({
        filePath,
        config: {
          ...DEFAULT_CONFIG,
          transcription: {
            ...DEFAULT_CONFIG.transcription,
            provider: "openai-compatible",
            baseUrl: "https://example.test/v1"
          }
        },
        prompt
      }),
      /No speech detected/
    );
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv("OPENAI_API_KEY", previousKey);
  }
});

test("openai-compatible transcription handles mocked success and errors", async () => {
  const previousFetch = globalThis.fetch;
  const previousKey = process.env.OPENAI_API_KEY;
  process.env.OPENAI_API_KEY = "test-key";

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.webm");
  fs.writeFileSync(filePath, "mock");

  try {
    globalThis.fetch = async () => Response.json({ text: "fix the tests" });
    const success = await transcribeAudioFile({
      filePath,
      config: {
        ...DEFAULT_CONFIG,
        transcription: {
          ...DEFAULT_CONFIG.transcription,
          provider: "openai-compatible",
          baseUrl: "https://example.test/v1"
        }
      }
    });
    assert.equal(success.cleaned, "Fix the tests");

    globalThis.fetch = async () => Response.json({ error: { message: "bad audio" } }, { status: 400 });
    await assert.rejects(
      transcribeAudioFile({
        filePath,
        config: {
          ...DEFAULT_CONFIG,
          transcription: {
            ...DEFAULT_CONFIG.transcription,
            provider: "openai-compatible",
            baseUrl: "https://example.test/v1"
          }
        }
      }),
      /bad audio/
    );
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv("OPENAI_API_KEY", previousKey);
  }
});

test("azure transcription handles mocked success and errors", async () => {
  const previousFetch = globalThis.fetch;
  const previousKey = process.env.AZURE_OPENAI_API_KEY;
  process.env.AZURE_OPENAI_API_KEY = "test-key";

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.wav");
  fs.writeFileSync(filePath, "mock");

  const config = {
    ...DEFAULT_CONFIG,
    transcription: {
      ...DEFAULT_CONFIG.transcription,
      provider: "azure-openai",
      azureEndpoint: "https://example.openai.azure.com",
      azureDeployment: "voice-deploy"
    }
  };

  try {
    globalThis.fetch = async () => Response.json({ text: "ship the fix" });
    const success = await transcribeAudioFile({ filePath, config });
    assert.equal(success.cleaned, "Ship the fix");

    globalThis.fetch = async () => Response.json({ error: { message: "azure rejected it" } }, { status: 429 });
    await assert.rejects(transcribeAudioFile({ filePath, config }), /azure rejected it/);
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv("AZURE_OPENAI_API_KEY", previousKey);
  }
});

test("elevenlabs transcription handles mocked success and errors", async () => {
  const previousFetch = globalThis.fetch;
  const previousKey = process.env.ELEVENLABS_API_KEY;
  process.env.ELEVENLABS_API_KEY = "test-key";

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-transcribe-"));
  const filePath = path.join(dir, "sample.mp3");
  fs.writeFileSync(filePath, "mock");

  const config = {
    ...DEFAULT_CONFIG,
    transcription: {
      ...DEFAULT_CONFIG.transcription,
      provider: "elevenlabs"
    }
  };

  try {
    globalThis.fetch = async () => Response.json({ text: "write a test" });
    const success = await transcribeAudioFile({ filePath, config });
    assert.equal(success.cleaned, "Write a test");

    globalThis.fetch = async () => Response.json({ detail: { message: "quota exceeded" } }, { status: 402 });
    await assert.rejects(transcribeAudioFile({ filePath, config }), /quota exceeded/);
  } finally {
    globalThis.fetch = previousFetch;
    restoreEnv("ELEVENLABS_API_KEY", previousKey);
  }
});

function restoreEnv(key, value) {
  if (value === undefined) {
    delete process.env[key];
  } else {
    process.env[key] = value;
  }
}
