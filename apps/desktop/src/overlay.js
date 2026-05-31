const statusEl = document.getElementById("status");
const metaEl = document.getElementById("meta");
const pulseEl = document.getElementById("pulse");
const taskEl = document.getElementById("task");
const resultEl = document.getElementById("result");
const runButton = document.getElementById("run");
const stopButton = document.getElementById("stop");
const agentButton = document.getElementById("agent");

let mediaRecorder;
let chunks = [];
let settings = {};

window.workerflow.getSettings().then((value) => {
  settings = value;
  renderMeta();
});

window.workerflow.onOverlayStatus((payload) => {
  settings = payload.settings ?? settings;
  setStatus(payload.status ?? "ready");
  renderMeta();
});

window.workerflow.onRecordingStart(async () => {
  setStatus("listening");
  resultEl.textContent = "";
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
  setStatus(payload.risk === "high" ? "review" : "ready");
  taskEl.value = payload.task ?? payload.transcript ?? "";
  resultEl.textContent = `${payload.mode} · ${payload.risk} risk`;
});

window.workerflow.onTaskError((payload) => {
  setStatus("ready");
  resultEl.textContent = payload.message;
});

window.workerflow.onJobStatus((payload) => {
  setStatus(payload.status === "running" ? "running" : "ready");
  resultEl.textContent = payload.message ?? payload.status;
});

runButton.addEventListener("click", async () => {
  const task = taskEl.value.trim();
  if (!task) return;

  setStatus("running");
  resultEl.textContent = "Starting job";
  const response = await window.workerflow.runJob({ task });
  if (!response.ok) {
    setStatus("ready");
    resultEl.textContent = response.error;
  }
});

stopButton.addEventListener("click", () => {
  window.workerflow.stopRecording();
  setStatus("ready");
});

agentButton.addEventListener("click", async () => {
  const nextAgent = settings.agent === "codex" ? "claude" : "codex";
  settings = await window.workerflow.updateSettings({ agent: nextAgent });
  renderMeta();
});

function setStatus(value) {
  const labels = {
    ready: "Ready",
    listening: "Listening",
    transcribing: "Transcribing",
    review: "Review",
    running: "Running"
  };

  statusEl.textContent = labels[value] ?? value;
  pulseEl.className = `pulse ${value === "listening" ? "listening" : value === "running" ? "running" : ""}`;
}

function renderMeta() {
  agentButton.textContent = settings.agent === "claude" ? "Claude" : "Codex";
  const repo = settings.activeRepo?.split("/").filter(Boolean).at(-1) ?? "repo";
  metaEl.textContent = `${settings.agent ?? "codex"} · ${repo} · ${settings.hotkey ?? "Alt+Space"}`;
}
