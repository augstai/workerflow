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

test("buildAgentPrompt includes optional screen context summary", () => {
  const prompt = buildAgentPrompt({
    task: "Use the visible terminal error to fix the task.",
    config: DEFAULT_CONFIG,
    context: {
      repoRoot: "/repo",
      branch: "main",
      changedFiles: [],
      packageManager: "pnpm",
      projectFiles: ["package.json"]
    },
    screenContext: {
      displayCount: 2,
      displays: [
        { label: "screen 1 of 2 - cursor is here", isCursorScreen: true },
        { label: "screen 2 of 2", isCursorScreen: false }
      ]
    }
  });

  assert.match(prompt, /Screen context:/);
  assert.match(prompt, /captured displays: 2/);
  assert.match(prompt, /cursor display: screen 1 of 2 - cursor is here/);
});
