import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { createJob, updateJob } from "../src/index.js";
import { commitFile, initGitRepo, makeTempDir, readFile, withEnv } from "./helpers.js";

const CLI_PATH = path.resolve("apps/cli/bin/workerflow.js");

test("CLI attach, status, prompt, run dry-run, and job show use isolated state", async () => {
  const home = makeTempDir("workerflow-home-");
  await withEnv({ WORKERFLOW_HOME: home }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");

    assertRun(repo, ["attach", "--agent", "codex", "--test", "node --test"]);
    const status = assertRun(repo, ["status"]);
    assert.match(status.stdout, /Workerflow status/);
    assert.match(status.stdout, /Worktree: enabled/);

    const prompt = assertRun(repo, ["prompt", "Fix", "the", "test"]);
    assert.match(prompt.stdout, /User task:\nFix the test/);

    const dryRun = assertRun(repo, ["run", "--dry-run", "Fix", "the", "test"]);
    assert.match(dryRun.stdout, /Status: dry-run/);

    const jobId = dryRun.stdout.match(/Job: (job_[^\n]+)/)?.[1];
    assert.ok(jobId);
    const shown = assertRun(repo, ["job", "show", jobId]);
    assert.match(shown.stdout, new RegExp(jobId));
    assert.equal(fs.existsSync(path.join(home, "jobs.json")), true);
  });
});

test("CLI job apply and reject operate through the isolated job store", async () => {
  const home = makeTempDir("workerflow-home-");
  await withEnv({ WORKERFLOW_HOME: home }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");

    const applyJob = readyJob(repo);
    fs.writeFileSync(path.join(applyJob.artifactsDir, "diff.patch"), patchAddingTwo());
    const applied = assertRun(repo, ["job", "apply", applyJob.id]);
    assert.match(applied.stdout, /Status: applied/);
    assert.equal(readFile(repo, "tracked.txt"), "one\ntwo\n");

    const rejectJob = readyJob(repo);
    fs.writeFileSync(path.join(rejectJob.artifactsDir, "diff.patch"), patchAddingThree());
    const rejected = assertRun(repo, ["job", "reject", rejectJob.id]);
    assert.match(rejected.stdout, /Status: rejected/);
    assert.equal(readFile(repo, "tracked.txt"), "one\ntwo\n");
  });
});

function assertRun(cwd, args) {
  const result = spawnSync(process.execPath, [CLI_PATH, ...args], {
    cwd,
    encoding: "utf8",
    env: {
      ...process.env,
      HOME: process.env.WORKERFLOW_HOME,
      WORKERFLOW_HOME: process.env.WORKERFLOW_HOME
    }
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result;
}

function readyJob(repoRoot) {
  const job = createJob({ task: "test", repoRoot, branch: "main", agent: "codex", prompt: "prompt" });
  return updateJob(job.id, { status: "ready" });
}

function patchAddingTwo() {
  return `diff --git a/tracked.txt b/tracked.txt
index 5626abf..814f4a4 100644
--- a/tracked.txt
+++ b/tracked.txt
@@ -1 +1,2 @@
 one
+two
`;
}

function patchAddingThree() {
  return `diff --git a/tracked.txt b/tracked.txt
index 814f4a4..4cb29ea 100644
--- a/tracked.txt
+++ b/tracked.txt
@@ -1,2 +1,3 @@
 one
 two
+three
`;
}
