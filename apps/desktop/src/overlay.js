const statusEl = document.getElementById("status");
const metaEl = document.getElementById("meta");
const pulseEl = document.getElementById("pulse");
const taskEl = document.getElementById("task");
const resultEl = document.getElementById("result");
const confirmEl = document.getElementById("confirm");
const confirmTitleEl = document.getElementById("confirmTitle");
const confirmAgentEl = document.getElementById("confirmAgent");
const confirmRepoEl = document.getElementById("confirmRepo");
const confirmBranchEl = document.getElementById("confirmBranch");
const confirmRiskEl = document.getElementById("confirmRisk");
const resultPanelEl = document.getElementById("resultPanel");
const resultTitleEl = document.getElementById("resultTitle");
const filesCountEl = document.getElementById("filesCount");
const checksStateEl = document.getElementById("checksState");
const filesListEl = document.getElementById("filesList");
const checksListEl = document.getElementById("checksList");
const openArtifactsButton = document.getElementById("openArtifacts");
const repoButton = document.getElementById("repo");
const agentSelect = document.getElementById("agent");
const hotkeyInput = document.getElementById("hotkey");
const hotkeyModeSelect = document.getElementById("hotkeyMode");
const providerSelect = document.getElementById("provider");
const modelInput = document.getElementById("model");
const reviewButton = document.getElementById("review");
const runButton = document.getElementById("run");
const stopButton = document.getElementById("stop");

let mediaRecorder;
let chunks = [];
let settings = {};
let context = {};
let confirmation = null;
let lastJob = null;

window.workerflow.getSettings().then((payload) => {
  settings = payload.settings;
  context = payload.context;
  renderAll();
});

window.workerflow.onOverlayStatus((payload) => {
  settings = payload.settings ?? settings;
  context = payload.context ?? context;
  setStatus(payload.status ?? "ready");
  renderAll();
});

window.workerflow.onRecordingStart(async () => {
  setStatus("listening");
  resultEl.textContent = "";
  resetResult();
  chunks = [];

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder = new MediaRecorder(stream, { mimeType: "audio/webm" });
    mediaRecorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.push(event.data);
    };
    mediaRecorder.onstop = async () => {
      stream.getTracks().forEach((track) => track.stop());
      const blob = new Blob(chunks, { type: "audio/webm" });
      const buffer = await blob.arrayBuffer();
      setStatus("transcribing");
      await window.workerflow.sendAudio(buffer);
    };
    mediaRecorder.start();
  } catch (error) {
    await window.workerflow.recordingFailed();
    setStatus("ready");
    resultEl.textContent = error.message;
  }
});

window.workerflow.onRecordingStop(() => {
  if (mediaRecorder && mediaRecorder.state !== "inactive") {
    mediaRecorder.stop();
  }
});

window.workerflow.onTaskReady((payload) => {
  taskEl.value = payload.task ?? payload.transcript ?? "";
  context = payload.context ?? context;
  setConfirmation(payload);
});

window.workerflow.onTaskError((payload) => {
  setStatus("ready");
  resultEl.textContent = payload.message;
});

window.workerflow.onJobStatus((payload) => {
  setStatus(statusToView(payload.status));
  resultEl.textContent = payload.message ?? payload.status;
  if (payload.job) {
    renderJob(payload.job);
  }
  if (payload.context) {
    context = payload.context;
    renderMeta();
  }
});

repoButton.addEventListener("click", async () => {
  const response = await window.workerflow.chooseRepo();
  if (!response.canceled) {
    settings = response.settings;
    context = response.context;
    resetConfirmation();
    renderAll();
  }
});

agentSelect.addEventListener("change", async () => {
  settings = await window.workerflow.updateSettings({ agent: agentSelect.value });
  renderAll();
});

hotkeyInput.addEventListener("change", async () => {
  settings = await window.workerflow.updateSettings({ hotkey: hotkeyInput.value.trim() || "Alt+Space" });
  renderAll();
});

hotkeyModeSelect.addEventListener("change", async () => {
  settings = await window.workerflow.updateSettings({ hotkeyMode: hotkeyModeSelect.value });
  renderAll();
});

providerSelect.addEventListener("change", async () => {
  settings = await window.workerflow.updateSettings({
    transcription: {
      provider: providerSelect.value
    }
  });
  renderAll();
});

modelInput.addEventListener("change", async () => {
  settings = await window.workerflow.updateSettings({
    transcription: {
      model: modelInput.value.trim()
    }
  });
  renderAll();
});

reviewButton.addEventListener("click", async () => {
  const task = taskEl.value.trim();
  if (!task) return;

  const response = await window.workerflow.interpretTask({ task });
  settings = response.settings ?? settings;
  context = response.context ?? context;
  setConfirmation(response);
});

runButton.addEventListener("click", async () => {
  const task = confirmation?.task || taskEl.value.trim();
  if (!task) return;

  setStatus("running");
  resultEl.textContent = "Starting job";
  runButton.disabled = true;
  reviewButton.disabled = true;
  const response = await window.workerflow.runJob({ task });
  reviewButton.disabled = false;
  if (!response.ok) {
    setStatus("failed");
    resultEl.textContent = response.error;
  }
});

stopButton.addEventListener("click", () => {
  window.workerflow.stopRecording();
  setStatus("ready");
});

openArtifactsButton.addEventListener("click", () => {
  if (lastJob?.artifactsDir) {
    window.workerflow.openPath(lastJob.artifactsDir);
  }
});

taskEl.addEventListener("input", () => {
  resetConfirmation();
});

function setConfirmation(payload) {
  confirmation = payload;
  confirmTitleEl.textContent = payload.task;
  confirmAgentEl.textContent = settings.agentLabel ?? formatAgent(settings.agent);
  confirmRepoEl.textContent = repoName();
  confirmBranchEl.textContent = context.branch || "no branch";
  confirmRiskEl.textContent = `${payload.risk} risk`;
  confirmEl.hidden = false;
  runButton.disabled = payload.mode === "dictation";
  resultEl.textContent = payload.mode === "dictation" ? "Dictation mode" : "Ready to run";
  setStatus(payload.risk === "high" ? "review" : "ready");
}

function resetConfirmation() {
  confirmation = null;
  confirmEl.hidden = true;
  runButton.disabled = true;
}

function renderJob(job) {
  lastJob = job;
  resultPanelEl.hidden = false;
  resultTitleEl.textContent = job.summary ?? job.status;
  filesCountEl.textContent = String(job.filesChanged?.length ?? 0);
  filesListEl.textContent = job.filesChanged?.length ? job.filesChanged.join("\n") : "No files changed.";

  const checks = job.verification ?? [];
  const checksPassed = checks.length > 0 && checks.every((item) => item.code === 0);
  checksStateEl.textContent = checks.length ? (checksPassed ? "passed" : "failed") : "not run";
  checksListEl.textContent = checks.length
    ? checks.map((item) => `${item.name}: ${item.code === 0 ? "passed" : "failed"} · ${item.command}`).join("\n")
    : "No verification configured.";
}

function resetResult() {
  lastJob = null;
  resultPanelEl.hidden = true;
}

function setStatus(value) {
  const labels = {
    ready: "Ready",
    listening: "Listening",
    transcribing: "Transcribing",
    review: "Review",
    running: "Running",
    failed: "Needs attention"
  };

  statusEl.textContent = labels[value] ?? value;
  pulseEl.className = `pulse ${["listening", "running", "review", "failed"].includes(value) ? value : ""}`;
}

function renderAll() {
  renderMeta();
  agentSelect.value = settings.agent ?? "codex";
  hotkeyInput.value = settings.hotkey ?? "Alt+Space";
  hotkeyModeSelect.value = settings.hotkeyMode ?? "toggle";
  providerSelect.value = settings.transcription?.provider ?? "mock";
  modelInput.value = settings.transcription?.model ?? settings.transcription?.elevenLabsModel ?? "";
}

function renderMeta() {
  repoButton.textContent = repoName();
  metaEl.textContent = `${settings.agentLabel ?? formatAgent(settings.agent)} · ${repoName()} · ${
    settings.hotkeyLabel ?? settings.hotkey ?? "Option+Space"
  }`;
}

function repoName() {
  return context.repoRoot?.split("/").filter(Boolean).at(-1) ?? settings.activeRepo?.split("/").filter(Boolean).at(-1) ?? "repo";
}

function formatAgent(value) {
  return value === "claude" ? "Claude" : "Codex";
}

function statusToView(value) {
  if (["running", "preparing", "queued", "verifying"].includes(value)) return "running";
  if (["failed", "needs-attention"].includes(value)) return "failed";
  return "ready";
}
