export function viewStatusToVoiceButtonState(status) {
  if (status === "listening") return "recording";
  if (status === "transcribing" || status === "running") return "processing";
  if (status === "failed") return "error";
  return "idle";
}

export function statusToView(value) {
  if (value === "listening") return "listening";
  if (value === "transcribing") return "transcribing";
  if (value === "review") return "review";
  if (["running", "preparing", "queued", "verifying"].includes(value)) return "running";
  if (["failed", "needs-attention"].includes(value)) return "failed";
  return "ready";
}

export function statusLabel(status) {
  const labels = {
    ready: "Ready",
    listening: "Listening",
    transcribing: "Transcribing",
    review: "Review",
    running: "Running",
    failed: "Needs attention"
  };
  return labels[status];
}

export function statusSubtitle(status, settings, repo) {
  if (status === "listening") return `Recording for ${repo}`;
  if (status === "transcribing") return `${providerLabel(settings.transcription.provider)} is transcribing`;
  if (status === "running") return `${settings.agentLabel ?? formatAgent(settings.agent)} is working`;
  if (status === "review") return "Approval needed";
  if (status === "failed") return "Check voice or provider settings";
  return `${settings.agentLabel ?? formatAgent(settings.agent)} -> ${repo}`;
}

export function voiceActionLabel(status) {
  if (status === "listening") return "Stop recording";
  if (status === "transcribing") return "Transcribing";
  if (status === "running") return "Running";
  if (status === "failed") return "Try again";
  return "Speak task";
}

export function providerLabel(value) {
  const labels = {
    "azure-openai": "Azure",
    elevenlabs: "ElevenLabs",
    mock: "Mock",
    openai: "OpenAI",
    "openai-compatible": "Compatible"
  };
  return labels[value ?? "mock"] ?? value ?? "Mock";
}

export function repoName(context, settings) {
  return context.repoRoot?.split("/").filter(Boolean).at(-1) ?? settings.activeRepo?.split("/").filter(Boolean).at(-1) ?? "repo";
}

export function formatAgent(value) {
  return value === "claude" ? "Claude" : "Codex";
}

export function canRunTask(confirmation, task) {
  const nextTask = (confirmation?.task || task).trim();
  return Boolean(nextTask) && confirmation?.mode !== "dictation";
}
