import { runCommand } from "../packages/core/src/index.js";

const agents = [
  {
    name: "codex",
    command: "codex",
    args: ["--ask-for-approval", "never", "exec", "--cd", process.cwd(), "--sandbox", "read-only", "--color", "never", "-"],
    input: "Say exactly: workerflow-codex-ok"
  },
  {
    name: "claude",
    command: "claude",
    args: ["-p", "--permission-mode", "dontAsk", "--output-format", "text", "--no-session-persistence", "Say exactly: workerflow-claude-ok"],
    input: ""
  }
];

let failed = false;

for (const agent of agents) {
  console.log(`Smoke: ${agent.name}`);
  const result = await runCommand({
    command: agent.command,
    args: agent.args,
    cwd: process.cwd(),
    input: agent.input,
    timeoutMs: 20000
  });
  const output = `${result.stdout}${result.stderr}`.trim();
  console.log(`${result.code === 0 ? "ok" : "failed"}  exit=${result.code}${result.timedOut ? " timed-out" : ""}`);
  if (output) {
    console.log(output.split("\n").slice(0, 8).join("\n"));
  }
  failed ||= result.code !== 0;
  console.log("");
}

if (failed) {
  process.exit(1);
}
