import { DEFAULT_SAFETY_RULES } from "./safety.js";

export function buildAgentPrompt({ task, config, context }) {
  const commands = config.commands ?? {};
  const denyPaths = config.denyPaths ?? [];

  return `You are running inside an isolated Workerflow job.

User task:
${task}

Rules:
${DEFAULT_SAFETY_RULES.map((rule) => `- ${rule}`).join("\n")}
${denyPaths.length ? `- Treat these paths as restricted: ${denyPaths.join(", ")}` : ""}

Repo context:
- repo root: ${context.repoRoot}
- branch: ${context.branch || "unknown"}
- package manager: ${context.packageManager || "unknown"}
- changed files: ${context.changedFiles.length ? context.changedFiles.join(", ") : "none"}
- project files: ${context.projectFiles.length ? context.projectFiles.join(", ") : "none"}

Verification commands:
- test: ${commands.test || "not configured"}
- build: ${commands.build || "not configured"}
- lint: ${commands.lint || "not configured"}

Expected result:
- Keep the diff minimal.
- Run the relevant verification command when possible.
- Do not push, deploy, or publish anything.
- Write a concise result summary with files changed, commands run, test result, risks, and followups.
`;
}
