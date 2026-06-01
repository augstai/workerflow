import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { captureDiff, createWorktree, makeWorktreePlan } from "../src/index.js";
import { commitFile, git, initGitRepo, writeFile } from "./helpers.js";

test("makeWorktreePlan creates stable branch and path", () => {
  const plan = makeWorktreePlan({
    repoRoot: "/tmp/example",
    jobId: "job_123"
  });

  assert.equal(plan.branch, "workerflow/job_123");
  assert.equal(plan.path, "/tmp/example-workerflow-job_123");
});

test("captureDiff includes unstaged tracked edits", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  writeFile(repo, "tracked.txt", "one\ntwo\n");

  const diff = captureDiff(repo);

  assert.deepEqual(diff.nameOnly, ["tracked.txt"]);
  assert.match(diff.stat, /tracked\.txt/);
  assert.match(diff.patch, /\+two/);
});

test("captureDiff includes staged edits", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  writeFile(repo, "tracked.txt", "one\ntwo\n");
  git(repo, ["add", "tracked.txt"]);

  const diff = captureDiff(repo);

  assert.deepEqual(diff.nameOnly, ["tracked.txt"]);
  assert.match(diff.patch, /\+two/);
});

test("captureDiff includes untracked new files", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  writeFile(repo, "new.txt", "new\n");

  const diff = captureDiff(repo);

  assert.deepEqual(diff.nameOnly, ["new.txt"]);
  assert.match(diff.stat, /new\.txt/);
  assert.match(diff.patch, /new file mode/);
  assert.match(diff.patch, /\+new/);
});

test("captureDiff includes deleted files", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  fs.unlinkSync(path.join(repo, "tracked.txt"));

  const diff = captureDiff(repo);

  assert.deepEqual(diff.nameOnly, ["tracked.txt"]);
  assert.match(diff.patch, /deleted file mode/);
});

test("captureDiff includes binary file patches", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  writeFile(repo, "image.bin", Buffer.from([0, 159, 146, 150, 0, 1, 2]));

  const diff = captureDiff(repo);

  assert.deepEqual(diff.nameOnly, ["image.bin"]);
  assert.match(diff.patch, /GIT binary patch|Binary files/);
});

test("createWorktree throws when the planned path already exists", () => {
  const repo = initGitRepo();
  commitFile(repo, "tracked.txt", "one\n");
  const plan = makeWorktreePlan({ repoRoot: repo, jobId: "job_exists" });
  fs.mkdirSync(plan.path, { recursive: true });

  assert.throws(
    () => createWorktree({ repoRoot: repo, jobId: "job_exists" }),
    /Worktree path already exists/
  );
});
