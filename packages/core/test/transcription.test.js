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
