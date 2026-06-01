import fs from "node:fs";
import path from "node:path";
import { git, gitText } from "./git.js";

export function makeWorktreePlan({ repoRoot, jobId }) {
  const parent = path.dirname(repoRoot);
  const repoName = path.basename(repoRoot);
  const safeJobId = jobId.replace(/[^a-zA-Z0-9_-]/g, "-");

  return {
    branch: `workerflow/${safeJobId}`,
    path: path.join(parent, `${repoName}-workerflow-${safeJobId}`)
  };
}

export function createWorktree({ repoRoot, jobId }) {
  const plan = makeWorktreePlan({ repoRoot, jobId });
  if (fs.existsSync(plan.path)) {
    throw new Error(`Worktree path already exists: ${plan.path}`);
  }

  const result = git(["worktree", "add", "-b", plan.branch, plan.path], repoRoot);
  if (!result.ok) {
    throw new Error(result.stderr || result.stdout || "Failed to create git worktree");
  }

  return plan;
}

export function captureDiff(workspaceDir) {
  const trackedPatch = gitText(["diff", "--binary", "HEAD"], workspaceDir);
  const trackedStat = gitText(["diff", "--stat", "HEAD"], workspaceDir);
  const trackedNames = splitLines(gitText(["diff", "--name-only", "HEAD"], workspaceDir));
  const untrackedFiles = listUntrackedFiles(workspaceDir);
  const untrackedDiffs = untrackedFiles.map((file) => diffUntrackedFile(workspaceDir, file));
  const patches = [trackedPatch, ...untrackedDiffs.map((diff) => diff.patch)].filter(Boolean);
  const stats = [trackedStat, ...untrackedDiffs.map((diff) => diff.stat)].filter(Boolean);

  return {
    stat: stats.join("\n"),
    nameOnly: unique([...trackedNames, ...untrackedFiles]),
    patch: patches.join("\n")
  };
}

function listUntrackedFiles(workspaceDir) {
  return gitText(["ls-files", "--others", "--exclude-standard", "-z"], workspaceDir)
    .split("\0")
    .map((line) => line.trim())
    .filter(Boolean);
}

function diffUntrackedFile(workspaceDir, file) {
  return {
    patch: gitDiffNoIndex(["diff", "--binary", "--no-index", "--", "/dev/null", file], workspaceDir),
    stat: gitDiffNoIndex(["diff", "--stat", "--no-index", "--", "/dev/null", file], workspaceDir)
  };
}

function gitDiffNoIndex(args, cwd) {
  const result = git(args, cwd);
  if (result.status === 0 || result.status === 1) {
    return result.stdout;
  }
  return "";
}

function splitLines(value) {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function unique(values) {
  return [...new Set(values)];
}
