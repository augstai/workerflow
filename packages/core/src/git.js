import { spawnSync } from "node:child_process";

export function git(args, cwd, options = {}) {
  const result = spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options
  });

  return {
    ok: result.status === 0,
    status: result.status ?? 1,
    stdout: result.stdout?.trim() ?? "",
    stderr: result.stderr?.trim() ?? ""
  };
}

export function gitText(args, cwd) {
  const result = git(args, cwd);
  return result.ok ? result.stdout : "";
}
