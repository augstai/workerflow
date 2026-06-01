import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createDiagnosticsBundle, redactDiagnosticsText } from "../src/index.js";

test("redactDiagnosticsText removes common secret values", () => {
  const redacted = redactDiagnosticsText(`
    AZURE_OPENAI_API_KEY=<your-api-key>
    Authorization: Bearer fake-openai-token-value
    x-api-key: abcdefghijklmnop
  `);

  assert.equal(redacted.includes("<your-api-key>"), false);
  assert.equal(redacted.includes("fake-openai-token-value"), false);
  assert.equal(redacted.includes("abcdefghijklmnop"), false);
  assert.match(redacted, /AZURE_OPENAI_API_KEY=\[REDACTED\]/);
  assert.equal(redactDiagnosticsText("AZURE_OPENAI_API_KEY: set").includes("set"), true);
});

test("createDiagnosticsBundle writes safe bundle files", () => {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-diagnostics-cwd-"));
  const outputRoot = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-diagnostics-out-"));
  fs.writeFileSync(path.join(cwd, "package.json"), "{}\n");

  const bundle = createDiagnosticsBundle({
    cwd,
    outputRoot,
    loadedEnvFiles: [{ path: path.join(cwd, ".env"), keys: ["AZURE_OPENAI_API_KEY"], applied: 0 }],
    jobs: [
      {
        id: "job_1",
        status: "failed",
        agent: "codex",
        repoRoot: cwd,
        branch: "main",
        artifactsDir: path.join(cwd, "missing-artifacts"),
        error: "AZURE_OPENAI_API_KEY=<your-api-key>"
      }
    ],
    now: new Date("2026-01-02T03:04:05.000Z")
  });

  assert.equal(fs.existsSync(path.join(bundle.path, "summary.json")), true);
  assert.equal(fs.existsSync(path.join(bundle.path, "recent-jobs.json")), true);
  assert.equal(fs.existsSync(path.join(bundle.path, "status.txt")), true);

  const summary = fs.readFileSync(path.join(bundle.path, "summary.json"), "utf8");
  const jobs = fs.readFileSync(path.join(bundle.path, "recent-jobs.json"), "utf8");
  assert.equal(summary.includes("<your-api-key>"), false);
  assert.equal(jobs.includes("<your-api-key>"), false);
});
