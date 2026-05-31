import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { DEFAULT_CONFIG, readProjectConfig, writeProjectConfig } from "../src/index.js";

test("writeProjectConfig writes a merged config file", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workerflow-config-"));

  const result = writeProjectConfig(dir, {
    agent: "claude",
    commands: {
      test: "pnpm test"
    }
  });

  assert.equal(result.config.agent, "claude");
  assert.equal(result.config.commands.test, "pnpm test");
  assert.equal(result.config.commands.build, DEFAULT_CONFIG.commands.build);

  const loaded = readProjectConfig(dir);
  assert.equal(loaded.config.agent, "claude");
});
