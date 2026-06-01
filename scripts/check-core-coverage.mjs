import fs from "node:fs";
import { spawnSync } from "node:child_process";

const testFiles = fs
  .readdirSync("packages/core/test")
  .filter((file) => file.endsWith(".test.js"))
  .map((file) => `packages/core/test/${file}`);

const targets = [
  { label: "core source", include: "packages/core/src/**/*.js", lines: 80 },
  { label: "adapters", include: "packages/core/src/adapters.js", lines: 85 },
  { label: "commands", include: "packages/core/src/commands.js", lines: 85 },
  { label: "jobs", include: "packages/core/src/jobs.js", lines: 85 },
  { label: "runner", include: "packages/core/src/runner.js", lines: 85 },
  { label: "worktree", include: "packages/core/src/worktree.js", lines: 85 }
];

for (const target of targets) {
  console.log(`\nCore coverage target: ${target.label} (${target.lines}% lines)`);
  const result = spawnSync(
    process.execPath,
    [
      "--test",
      "--experimental-test-coverage",
      `--test-coverage-include=${target.include}`,
      `--test-coverage-lines=${target.lines}`,
      ...testFiles
    ],
    {
      encoding: "utf8",
      stdio: "inherit"
    }
  );

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
