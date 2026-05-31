import assert from "node:assert/strict";
import test from "node:test";
import { buildAgentPrompt, DEFAULT_CONFIG } from "../src/index.js";

test("buildAgentPrompt includes task, repo context, and safety rules", () => {
  const prompt = buildAgentPrompt({
    task: "Fix the failing test.",
    config: {
      ...DEFAULT_CONFIG,
      commands: {
        test: "pnpm test"
      }
    },
    context: {
      repoRoot: "/repo",
      branch: "main",
      changedFiles: ["src/auth.test.js"],
      packageManager: "pnpm",
      projectFiles: ["package.json", "README.md"]
    }
  });

  assert.match(prompt, /Fix the failing test/);
  assert.match(prompt, /Do not push/);
  assert.match(prompt, /src\/auth\.test\.js/);
  assert.match(prompt, /pnpm test/);
});
