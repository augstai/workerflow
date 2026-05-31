import fs from "node:fs";
import path from "node:path";
import { gitText } from "./git.js";

export function captureRepoContext(cwd) {
  const repoRoot = gitText(["rev-parse", "--show-toplevel"], cwd) || cwd;
  const branch = gitText(["branch", "--show-current"], repoRoot);
  const status = gitText(["status", "--short"], repoRoot);
  const diffStat = gitText(["diff", "--stat"], repoRoot);
  const head = gitText(["rev-parse", "--short", "HEAD"], repoRoot);
  const changedFiles = status
    ? status
        .split("\n")
        .map((line) => line.slice(3).trim())
        .filter(Boolean)
    : [];

  return {
    repoRoot,
    branch,
    head,
    changedFiles,
    diffStat,
    packageManager: detectPackageManager(repoRoot),
    projectFiles: detectProjectFiles(repoRoot)
  };
}

function detectPackageManager(repoRoot) {
  if (exists(repoRoot, "pnpm-lock.yaml")) return "pnpm";
  if (exists(repoRoot, "yarn.lock")) return "yarn";
  if (exists(repoRoot, "package-lock.json")) return "npm";
  if (exists(repoRoot, "bun.lockb") || exists(repoRoot, "bun.lock")) return "bun";
  return exists(repoRoot, "package.json") ? "npm" : null;
}

function detectProjectFiles(repoRoot) {
  return [
    "package.json",
    "pnpm-workspace.yaml",
    "pyproject.toml",
    "Cargo.toml",
    "README.md",
    "AGENTS.md",
    "CLAUDE.md"
  ].filter((file) => exists(repoRoot, file));
}

function exists(repoRoot, file) {
  return fs.existsSync(path.join(repoRoot, file));
}
