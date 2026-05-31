export const SUPPORTED_AGENTS = Object.freeze(["codex", "claude"]);

export function normalizeAgent(agent) {
  const normalized = (agent ?? "codex").toLowerCase();
  if (!SUPPORTED_AGENTS.includes(normalized)) {
    throw new Error(`Unsupported agent "${agent}". Supported agents: ${SUPPORTED_AGENTS.join(", ")}`);
  }
  return normalized;
}

export function buildAdapterInvocation({ agent, config, workspaceDir, resultPath }) {
  const normalized = normalizeAgent(agent);

  if (normalized === "codex") {
    const adapterConfig = config.adapters?.codex ?? {};
    const args = [
      "--ask-for-approval",
      adapterConfig.approvalPolicy ?? "never",
      "exec",
      "--cd",
      workspaceDir,
      "--sandbox",
      adapterConfig.sandbox ?? "workspace-write",
      "--color",
      "never",
      "--output-last-message",
      resultPath
    ];

    if (adapterConfig.json) {
      args.push("--json");
    }

    args.push("-");
    return {
      command: "codex",
      args,
      stdin: true
    };
  }

  const adapterConfig = config.adapters?.claude ?? {};
  return {
    command: "claude",
    args: [
      "-p",
      "--permission-mode",
      adapterConfig.permissionMode ?? "dontAsk",
      "--output-format",
      adapterConfig.outputFormat ?? "json",
      "--no-session-persistence",
      "-"
    ],
    stdin: true
  };
}
