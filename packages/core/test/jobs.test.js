import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { applyJobPatch, createJob, getJob, rejectJob, updateJob } from "../src/index.js";
import { commitFile, initGitRepo, makeTempDir, readFile, withEnv, writeFile } from "./helpers.js";

test("applyJobPatch rejects unknown jobs", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    assert.throws(() => applyJobPatch("missing"), /Unknown Workerflow job/);
  });
});

test("applyJobPatch rejects non-ready jobs", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");
    const job = createJob({ task: "test", repoRoot: repo, branch: "main", agent: "codex", prompt: "prompt" });

    assert.throws(() => applyJobPatch(job.id), /not ready to apply/);
  });
});

test("applyJobPatch refuses patches that do not apply cleanly", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");
    writeFile(repo, "tracked.txt", "conflicting local edit\n");
    const job = readyJob(repo);
    fs.writeFileSync(
      path.join(job.artifactsDir, "diff.patch"),
      `diff --git a/tracked.txt b/tracked.txt
index 5626abf..814f4a4 100644
--- a/tracked.txt
+++ b/tracked.txt
@@ -1 +1,2 @@
 one
+two
`
    );

    assert.throws(() => applyJobPatch(job.id), /Patch does not apply cleanly/);
    assert.equal(readFile(repo, "tracked.txt"), "conflicting local edit\n");
  });
});

test("applyJobPatch handles empty diffs honestly", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");
    const job = readyJob(repo);
    fs.writeFileSync(path.join(job.artifactsDir, "diff.patch"), "");

    const applied = applyJobPatch(job.id);

    assert.equal(applied.status, "applied");
    assert.equal(applied.summary, "No diff to apply.");
  });
});

test("applyJobPatch applies and records ready patches", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");
    const job = readyJob(repo);
    fs.writeFileSync(
      path.join(job.artifactsDir, "diff.patch"),
      `diff --git a/tracked.txt b/tracked.txt
index 5626abf..814f4a4 100644
--- a/tracked.txt
+++ b/tracked.txt
@@ -1 +1,2 @@
 one
+two
`
    );

    const applied = applyJobPatch(job.id);

    assert.equal(applied.status, "applied");
    assert.equal(readFile(repo, "tracked.txt"), "one\ntwo\n");
    assert.equal(getJob(job.id).status, "applied");
  });
});

test("rejectJob records rejection without mutating the repo", async () => {
  await withEnv({ WORKERFLOW_HOME: makeTempDir("workerflow-home-") }, () => {
    const repo = initGitRepo();
    commitFile(repo, "tracked.txt", "one\n");
    const job = readyJob(repo);
    fs.writeFileSync(path.join(job.artifactsDir, "diff.patch"), "not applied");

    const rejected = rejectJob(job.id);

    assert.equal(rejected.status, "rejected");
    assert.equal(readFile(repo, "tracked.txt"), "one\n");
  });
});

function readyJob(repoRoot) {
  const job = createJob({ task: "test", repoRoot, branch: "main", agent: "codex", prompt: "prompt" });
  return updateJob(job.id, { status: "ready" });
}
