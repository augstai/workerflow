import { DEFAULT_SAFETY_RULES } from "./safety.js";

export function buildAgentPrompt({ task, config, context, screenContext }) {
  const commands = config.commands ?? {};
  const denyPaths = config.denyPaths ?? [];
  const screenContextSection = screenContext
    ? `
Screen context:
- captured displays: ${screenContext.displayCount ?? screenContext.displays?.length ?? "unknown"}
- cursor display: ${screenContext.displays?.find((display) => display.isCursorScreen)?.label ?? "unknown"}
- screenshots are saved in this job's screen-context artifact directory.
- Use screen details only when they help the coding task; do not assume private screen content is relevant.
`
    : "";

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
${screenContextSection}

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
