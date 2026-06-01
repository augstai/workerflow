import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { DEFAULT_CONFIG, readProjectConfig, runWorkerflowJob, writeProjectConfig } from "../src/index.js";
import { commitFile, initGitRepo, makeTempDir, readFile, withEnv, writeFile } from "./helpers.js";

test("runWorkerflowJob dry-run writes prompt and job metadata only", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig();

    const job = await runWorkerflowJob({
      task: "Fix the test",
      cwd: repo,
      dryRun: true
    });

    assert.equal(job.status, "dry-run");
    assert.equal(fs.realpathSync(job.workspaceDir), fs.realpathSync(repo));
    assert.equal(fs.existsSync(path.join(job.artifactsDir, "prompt.md")), true);
    assert.equal(fs.existsSync(path.join(job.artifactsDir, "agent-stdout.log")), false);
  });
});

test("runWorkerflowJob marks fake successful agent jobs ready and writes artifacts", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig({ commands: { test: "fake test" } });

    const job = await runWorkerflowJob({
      task: "Create a new file",
      cwd: repo,
      dependencies: {
        commandRunner: async ({ cwd }) => {
          writeFile(cwd, "created.txt", "created\n");
          return commandResult({ stdout: "Created file.\n" });
        },
        shellCommandRunner: async ({ command, cwd }) => commandResult({ command, cwd })
      }
    });

    assert.equal(job.status, "ready");
    assert.deepEqual(job.filesChanged, ["created.txt"]);
    assert.equal(job.verification[0].code, 0);
    assert.match(readArtifact(job, "agent-stdout.log"), /Created file/);
    assert.match(readArtifact(job, "diff.patch"), /created\.txt/);
    assert.match(readArtifact(job, "diff-stat.txt"), /created\.txt/);
    assert.match(readArtifact(job, "summary.md"), /Workerflow Result/);
  });
});

test("runWorkerflowJob marks failing agents as needs-attention", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig();

    const job = await runWorkerflowJob({
      task: "Fail",
      cwd: repo,
      dependencies: {
        commandRunner: async ({ cwd }) => commandResult({ code: 1, stderr: "agent failed\n", cwd }),
        shellCommandRunner: async ({ command, cwd }) => commandResult({ command, cwd })
      }
    });

    assert.equal(job.status, "needs-attention");
    assert.equal(job.agentExitCode, 1);
    assert.match(readArtifact(job, "agent-stderr.log"), /agent failed/);
  });
});

test("runWorkerflowJob marks failing verification as needs-attention", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig({ commands: { test: "fake test" } });

    const job = await runWorkerflowJob({
      task: "Create a file",
      cwd: repo,
      dependencies: {
        commandRunner: async ({ cwd }) => {
          writeFile(cwd, "created.txt", "created\n");
          return commandResult({ cwd });
        },
        shellCommandRunner: async ({ command, cwd }) => commandResult({ command, cwd, code: 1, stderr: "tests failed\n" })
      }
    });

    assert.equal(job.status, "needs-attention");
    assert.equal(job.verification[0].code, 1);
    assert.match(readArtifact(job, "verification.json"), /tests failed/);
  });
});

test("runWorkerflowJob copies screen context artifacts", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig();
    const screenContextDir = makeTempDir("workerflow-screen-");
    fs.writeFileSync(path.join(screenContextDir, "metadata.json"), JSON.stringify({ displayCount: 1, displays: [] }));
    fs.writeFileSync(path.join(screenContextDir, "screen-1.jpg"), "fake image");

    const job = await runWorkerflowJob({
      task: "Use screen context",
      cwd: repo,
      screenContextDir,
      dryRun: true
    });

    assert.equal(fs.existsSync(path.join(job.artifactsDir, "screen-context", "metadata.json")), true);
    assert.equal(fs.existsSync(path.join(job.artifactsDir, "screen-context", "screen-1.jpg")), true);
  });
});

test("runWorkerflowJob fails clearly when screen context metadata is missing", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, async () => {
    const repo = repoWithConfig();
    const screenContextDir = makeTempDir("workerflow-screen-");

    await assert.rejects(
      runWorkerflowJob({
        task: "Use screen context",
        cwd: repo,
        screenContextDir,
        dryRun: true
      }),
      /Missing screen context metadata/
    );
  });
});

function repoWithConfig(config = {}) {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  writeProjectConfig(repo, {
    ...DEFAULT_CONFIG,
    ...config,
    adapters: {
      ...DEFAULT_CONFIG.adapters,
      ...(config.adapters ?? {})
    },
    commands: {
      ...DEFAULT_CONFIG.commands,
      ...(config.commands ?? {})
    }
  });
  assert.equal(readProjectConfig(repo).config.agent, "codex");
  return repo;
}

function commandResult({
  command = "fake",
  args = [],
  cwd = "",
  code = 0,
  stdout = "",
  stderr = "",
  timedOut = false
} = {}) {
  return {
    command,
    args,
    cwd,
    code,
    signal: null,
    stdout,
    stderr,
    timedOut,
    startedAt: new Date("2026-01-01T00:00:00.000Z").toISOString(),
    finishedAt: new Date("2026-01-01T00:00:01.000Z").toISOString()
  };
}

function readArtifact(job, fileName) {
  return readFile(job.artifactsDir, fileName);
}
