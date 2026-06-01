import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

export function makeTempDir(prefix = "workerflow-test-") {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

export function initGitRepo(prefix = "workerflow-repo-") {
  const dir = makeTempDir(prefix);
  git(dir, ["init"]);
  git(dir, ["config", "user.email", "workerflow-test@example.com"]);
  git(dir, ["config", "user.name", "Workerflow Test"]);
  return dir;
}

export function commitFile(repoRoot, filePath, content, message = "initial commit") {
  writeFile(repoRoot, filePath, content);
  git(repoRoot, ["add", filePath]);
  git(repoRoot, ["commit", "-m", message]);
}

export function writeFile(repoRoot, filePath, content, encoding) {
  const fullPath = path.join(repoRoot, filePath);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, content, encoding);
}

export function readFile(repoRoot, filePath, encoding = "utf8") {
  return fs.readFileSync(path.join(repoRoot, filePath), encoding);
}

export function git(cwd, args, options = {}) {
  return execFileSync("git", args, {
    cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options
  }).trim();
}

export async function withEnv(patch, callback) {
  const previous = new Map();
  for (const key of Object.keys(patch)) {
    previous.set(key, process.env[key]);
    if (patch[key] === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = patch[key];
    }
  }

  try {
    return await callback();
  } finally {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}
