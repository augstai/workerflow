import assert from "node:assert/strict";
import test from "node:test";
import { commandExists, runCommand, runShellCommand } from "../src/index.js";

test("commandExists finds node", () => {
  const result = commandExists("node");
  assert.equal(result.ok, true);
  assert.match(result.path, /node/);
});

test("runCommand captures stdout, stderr, input, and exit code", async () => {
  const result = await runCommand({
    command: process.execPath,
    args: ["-e", "process.stdin.on('data', d => process.stdout.write(d)); process.stderr.write('warn')"],
    input: "hello"
  });

  assert.equal(result.code, 0);
  assert.equal(result.stdout, "hello");
  assert.equal(result.stderr, "warn");
  assert.equal(result.timedOut, false);
});

test("runCommand reports timeouts", async () => {
  const result = await runCommand({
    command: process.execPath,
    args: ["-e", "setTimeout(() => {}, 1000)"],
    timeoutMs: 20
  });

  assert.equal(result.timedOut, true);
  assert.match(result.stderr, /timed out/);
});

test("runShellCommand executes shell commands and captures output", async () => {
  const result = await runShellCommand({
    command: `${JSON.stringify(process.execPath)} -e "console.log('shell-ok')"`,
    cwd: process.cwd()
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /shell-ok/);
});
