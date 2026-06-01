import assert from "node:assert/strict";
import test from "node:test";
import { buildAdapterInvocation, DEFAULT_CONFIG, normalizeAgent } from "../src/index.js";

test("buildAdapterInvocation builds codex exec invocation", () => {
  const invocation = buildAdapterInvocation({
    agent: "codex",
    config: DEFAULT_CONFIG,
    workspaceDir: "/repo-worktree",
    resultPath: "/tmp/result.md"
  });

  assert.equal(invocation.command, "codex");
  assert.deepEqual(invocation.args.slice(0, 4), ["--ask-for-approval", "never", "exec", "--cd"]);
  assert.equal(invocation.args.at(-1), "-");
});

test("buildAdapterInvocation includes codex json output when configured", () => {
  const invocation = buildAdapterInvocation({
    agent: "codex",
    config: {
      ...DEFAULT_CONFIG,
      adapters: {
        ...DEFAULT_CONFIG.adapters,
        codex: {
          ...DEFAULT_CONFIG.adapters.codex,
          json: true
        }
      }
    },
    workspaceDir: "/repo-worktree",
    resultPath: "/tmp/result.md"
  });

  assert.equal(invocation.args.includes("--json"), true);
});

test("buildAdapterInvocation builds claude print invocation", () => {
  const invocation = buildAdapterInvocation({
    agent: "claude",
    config: DEFAULT_CONFIG,
    workspaceDir: "/repo-worktree",
    resultPath: "/tmp/result.md"
  });

  assert.equal(invocation.command, "claude");
  assert.equal(invocation.args[0], "-p");
  assert.equal(invocation.args.at(-1), "-");
});

test("normalizeAgent rejects unsupported agents", () => {
  assert.throws(() => normalizeAgent("aider"), /Unsupported agent/);
});
