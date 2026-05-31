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
  return {
    stat: gitText(["diff", "--stat"], workspaceDir),
    nameOnly: gitText(["diff", "--name-only"], workspaceDir)
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean),
    patch: gitText(["diff", "--binary"], workspaceDir)
  };
}
