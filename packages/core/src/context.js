import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

export function captureRepoContext(cwd) {
  const repoRoot = git(["rev-parse", "--show-toplevel"], cwd) || cwd;
  const branch = git(["branch", "--show-current"], repoRoot);
  const status = git(["status", "--short"], repoRoot);
  const diffStat = git(["diff", "--stat"], repoRoot);
  const changedFiles = status
    ? status
        .split("\n")
        .map((line) => line.slice(3).trim())
        .filter(Boolean)
    : [];

  return {
    repoRoot,
    branch,
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

function git(args, cwd) {
  const result = spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"]
  });

  if (result.status !== 0) {
    return "";
  }

  return result.stdout.trim();
}
