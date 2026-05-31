import React from "react";
import { createRoot } from "react-dom/client";
import { ArrowRight, Check, ChevronDown, Folder, Mic, Settings, Square, Zap } from "lucide-react";
import { VoiceButton, type VoiceButtonState } from "./components/elevenlabs-ui/voice-button";
import { Button } from "./components/elevenlabs-ui/button";
import { cn } from "./lib/utils";
import type { RepoContext, TaskPayload, WorkerflowBridge, WorkerflowJob, WorkerflowSettings } from "./types/workerflow";
import "./styles.css";

type ViewStatus = "ready" | "listening" | "transcribing" | "review" | "running" | "failed";
type CaptureMode = "task" | "test";

const initialSettings: WorkerflowSettings = {
  activeRepo: "",
  agent: "codex",
  agentLabel: "Codex",
  hotkey: "Alt+Space",
  hotkeyLabel: "Option+Space",
  hotkeyMode: "toggle",
  transcription: {
    provider: "mock"
  }
};

const initialContext: RepoContext = {
  repoRoot: "",
  branch: "",
  changedFiles: [],
  diffStat: "",
  packageManager: "",
  projectFiles: []
};

const workerflow = window.workerflow ?? createPreviewBridge();

function App() {
  const [settings, setSettings] = React.useState<WorkerflowSettings>(initialSettings);
  const [context, setContext] = React.useState<RepoContext>(initialContext);
  const [status, setStatus] = React.useState<ViewStatus>("ready");
  const [task, setTask] = React.useState("");
  const [transcript, setTranscript] = React.useState("");
  const [message, setMessage] = React.useState("");
  const [confirmation, setConfirmationState] = React.useState<TaskPayload | null>(null);
  const [job, setJob] = React.useState<WorkerflowJob | null>(null);
  const [settingsOpen, setSettingsOpen] = React.useState(false);

  const mediaRecorderRef = React.useRef<MediaRecorder | null>(null);
  const chunksRef = React.useRef<Blob[]>([]);
  const captureModeRef = React.useRef<CaptureMode>("task");
  const testTimerRef = React.useRef<number | null>(null);

  React.useEffect(() => {
    let mounted = true;

    workerflow.getSettings().then((payload) => {
      if (!mounted) return;
      setSettings(payload.settings);
      setContext(payload.context);
    });

    const unsubscribers = [
      workerflow.onOverlayStatus((payload) => {
        setSettings(payload.settings);
        setContext(payload.context);
        setStatus(statusToView(payload.status));
      }),
      workerflow.onRecordingStart((payload) => {
        void beginCapture(payload?.mode ?? "task");
      }),
      workerflow.onRecordingStop(() => {
        stopCapture();
      }),
      workerflow.onTaskReady((payload) => {
        setTranscript(payload.transcript ?? "");
        setTask(payload.task ?? payload.transcript ?? "");
        setConfirmation(payload);
      }),
      workerflow.onTaskError((payload) => {
        setStatus("failed");
        setMessage(payload.message);
      }),
      workerflow.onJobStatus((payload) => {
        setStatus(statusToView(payload.status));
        setMessage(payload.message ?? payload.status);
        if (payload.job) setJob(payload.job);
        if (payload.context) setContext(payload.context);
      })
    ];

    return () => {
      mounted = false;
      unsubscribers.forEach((unsubscribe) => unsubscribe());
      if (testTimerRef.current) {
        window.clearTimeout(testTimerRef.current);
        testTimerRef.current = null;
      }
    };
  }, []);

  async function beginCapture(mode: CaptureMode) {
    captureModeRef.current = mode;
    if (testTimerRef.current) window.clearTimeout(testTimerRef.current);

    setStatus("listening");
    setMessage("");
    setJob(null);
    chunksRef.current = [];

    try {
      const permission = await workerflow.requestMicrophoneAccess();
      if (!permission.ok) {
        throw new Error(`Microphone permission is ${permission.status}.`);
      }

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = preferredMimeType();
      const mediaRecorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
      mediaRecorderRef.current = mediaRecorder;

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunksRef.current.push(event.data);
      };

      mediaRecorder.onstop = async () => {
        stream.getTracks().forEach((track) => track.stop());
        if (!chunksRef.current.length) {
          setStatus("failed");
          setMessage("No audio was captured.");
          return;
        }

        const blob = new Blob(chunksRef.current, { type: mediaRecorder.mimeType || mimeType || "audio/webm" });
        const buffer = await blob.arrayBuffer();
        setStatus("transcribing");
        const response = await workerflow.sendAudio({ buffer, mode: captureModeRef.current });

        if (captureModeRef.current === "test") {
          if (!response.ok) {
            setStatus("failed");
            setMessage(response.error ?? "Transcription failed.");
            return;
          }
          setStatus("ready");
          setTranscript("transcript" in response ? response.transcript || response.cleaned || "" : "");
          setMessage(`${providerLabel(settings.transcription.provider)} transcription passed.`);
        }
      };

      mediaRecorder.start();
    } catch (error) {
      await workerflow.recordingFailed();
      setStatus("failed");
      setMessage(error instanceof Error ? error.message : String(error));
    }
  }

  function stopCapture() {
    if (testTimerRef.current) window.clearTimeout(testTimerRef.current);
    const recorder = mediaRecorderRef.current;
    if (recorder && recorder.state !== "inactive") {
      recorder.stop();
    }
  }

  function setConfirmation(payload: TaskPayload) {
    setConfirmationState(payload);
    setMessage(payload.mode === "dictation" ? "Dictation captured." : "Ready to hand off.");
    setStatus(payload.risk === "high" ? "review" : "ready");
  }

  async function chooseRepo() {
    const response = await workerflow.chooseRepo();
    if (!response.canceled) {
      setSettings(response.settings);
      if (response.context) setContext(response.context);
      setConfirmationState(null);
    }
  }

  async function reviewTask() {
    const nextTask = task.trim();
    if (!nextTask) return;
    const response = await workerflow.interpretTask({ task: nextTask });
    if (response.settings) setSettings(response.settings);
    if (response.context) setContext(response.context);
    setConfirmation(response);
  }

  async function runJob() {
    const nextTask = confirmation?.task || task.trim();
    if (!nextTask) return;

    setStatus("running");
    setMessage("Starting job.");
    const response = await workerflow.runJob({ task: nextTask });
    if (!response.ok) {
      setStatus("failed");
      setMessage(response.error ?? "Job failed.");
    }
  }

  async function testVoice() {
    const recorder = mediaRecorderRef.current;
    if (recorder && recorder.state !== "inactive") {
      stopCapture();
      return;
    }

    await beginCapture("test");
    testTimerRef.current = window.setTimeout(stopCapture, 3200);
  }

  async function updateSettings(patch: Partial<WorkerflowSettings>) {
    const next = await workerflow.updateSettings(patch);
    setSettings(next);
  }

  const voiceState = viewStatusToVoiceButtonState(status);
  const canRun = Boolean((confirmation?.task || task).trim()) && confirmation?.mode !== "dictation";
  const currentRepoName = repoName(context, settings);

  return (
    <main className="app-shell">
      <section className="wf-pill" data-state={status}>
        <div className="status-dot" />
        <div className="min-w-0 flex-1">
          <div className="status-line">{statusLabel(status)}</div>
          <div className="meta-line">
            {settings.agentLabel ?? formatAgent(settings.agent)} · {currentRepoName} · {settings.hotkeyLabel ?? "Option+Space"}
          </div>
        </div>
        <span className="provider-pill">{providerLabel(settings.transcription.provider)}</span>
      </section>

      <section className="command-panel">
        <div className="panel-topline">
          <Button variant="ghost" className="repo-button" onClick={chooseRepo}>
            <Folder className="size-4" />
            <span>{currentRepoName}</span>
          </Button>

          <select
            className="native-select"
            value={settings.agent}
            onChange={(event) => updateSettings({ agent: event.target.value as "codex" | "claude" })}
            aria-label="Agent"
          >
            <option value="codex">Codex</option>
            <option value="claude">Claude</option>
          </select>
        </div>

        <div className="voice-strip">
          <VoiceButton
            state={voiceState}
            label={voiceActionLabel(status)}
            trailing={settings.hotkeyLabel ?? "⌥ Space"}
            onPress={testVoice}
            className="voice-button"
            waveformClassName="voice-waveform"
          />
          <Button variant="ghost" size="icon" onClick={() => setSettingsOpen((value) => !value)} aria-label="Settings">
            {settingsOpen ? <ChevronDown className="size-4" /> : <Settings className="size-4" />}
          </Button>
        </div>

        <textarea
          className="task-input"
          spellCheck={false}
          placeholder="Say or type a coding task"
          value={task}
          onChange={(event) => {
            setTask(event.target.value);
            setConfirmationState(null);
          }}
        />

        <div className="transcript-line">{transcript || "Voice transcript appears here after a test or capture."}</div>

        {confirmation ? (
          <div className="confirmation">
            <div>
              <div className="eyebrow">Task understood</div>
              <div className="confirm-title">{confirmation.task}</div>
            </div>
            <div className="confirm-grid">
              <span>{settings.agentLabel ?? formatAgent(settings.agent)}</span>
              <span>{currentRepoName}</span>
              <span>{context.branch || "no branch"}</span>
              <span>{confirmation.risk} risk</span>
            </div>
          </div>
        ) : null}

        <div className="message-line">{message}</div>

        {job ? <JobResult job={job} /> : null}

        {settingsOpen ? (
          <SettingsPanel settings={settings} updateSettings={updateSettings} />
        ) : null}

        <div className="action-row">
          <Button variant="ghost" onClick={() => workerflow.stopRecording()}>
            <Square className="size-4" />
            Stop
          </Button>
          <Button variant="outline" onClick={reviewTask}>
            <Check className="size-4" />
            Review
          </Button>
          <Button onClick={runJob} disabled={!canRun}>
            <Zap className="size-4" />
            Run
            <ArrowRight className="size-4" />
          </Button>
        </div>
      </section>
    </main>
  );
}

function JobResult({ job }: { job: WorkerflowJob }) {
  const checks = job.verification ?? [];
  const checksPassed = checks.length > 0 && checks.every((item) => item.code === 0);
  const filesChanged = job.filesChanged ?? [];

  return (
    <section className="job-result">
      <div className="result-head">
        <div>
          <div className="eyebrow">Result</div>
          <div className="confirm-title">{job.summary ?? job.status}</div>
        </div>
        {job.artifactsDir ? (
          <Button variant="ghost" onClick={() => workerflow.openPath(job.artifactsDir ?? "")}>
            Artifacts
          </Button>
        ) : null}
      </div>
      <div className="stats-grid">
        <div>
          <span>Files</span>
          <strong>{filesChanged.length}</strong>
        </div>
        <div>
          <span>Checks</span>
          <strong>{checks.length ? (checksPassed ? "passed" : "failed") : "not run"}</strong>
        </div>
      </div>
      <pre>{filesChanged.length ? filesChanged.join("\n") : "No files changed."}</pre>
      <pre>{checks.length ? checks.map((item) => `${item.name}: ${item.code === 0 ? "passed" : "failed"} · ${item.command}`).join("\n") : "No verification configured."}</pre>
    </section>
  );
}

function SettingsPanel({
  settings,
  updateSettings
}: {
  settings: WorkerflowSettings;
  updateSettings: (patch: Partial<WorkerflowSettings>) => Promise<void>;
}) {
  const transcription = settings.transcription;
  const provider = transcription.provider ?? "mock";

  function updateTranscription(patch: Partial<WorkerflowSettings["transcription"]>) {
    return updateSettings({
      transcription: {
        ...transcription,
        ...patch
      }
    } as Partial<WorkerflowSettings>);
  }

  return (
    <section className="settings-panel">
      <label>
        <span>Hotkey</span>
        <input value={settings.hotkey} onChange={(event) => updateSettings({ hotkey: event.target.value || "Alt+Space" })} />
      </label>
      <label>
        <span>Mode</span>
        <select value={settings.hotkeyMode} onChange={(event) => updateSettings({ hotkeyMode: event.target.value as "toggle" | "hold" })}>
          <option value="toggle">Toggle</option>
          <option value="hold">Hold</option>
        </select>
      </label>
      <label>
        <span>Transcription</span>
        <select
          value={provider}
          onChange={(event) => {
            const nextProvider = event.target.value;
            if (nextProvider === "azure-openai") {
              void updateTranscription({
                provider: nextProvider,
                azureApiKeyEnv: "AZURE_OPENAI_API_KEY",
                azureApiVersion: "2025-03-01-preview"
              });
              return;
            }
            if (nextProvider === "elevenlabs") {
              void updateTranscription({
                provider: nextProvider,
                elevenLabsApiKeyEnv: "ELEVENLABS_API_KEY",
                elevenLabsModel: "scribe_v2"
              });
              return;
            }
            void updateTranscription({ provider: nextProvider });
          }}
        >
          <option value="mock">Mock</option>
          <option value="openai">OpenAI</option>
          <option value="azure-openai">Azure OpenAI</option>
          <option value="elevenlabs">ElevenLabs</option>
          <option value="openai-compatible">OpenAI-compatible</option>
        </select>
      </label>
      <label>
        <span>Model</span>
        <input
          value={provider === "elevenlabs" ? transcription.elevenLabsModel ?? "scribe_v2" : transcription.model ?? "gpt-4o-mini-transcribe"}
          onChange={(event) =>
            provider === "elevenlabs"
              ? updateTranscription({ elevenLabsModel: event.target.value || "scribe_v2" })
              : updateTranscription({ model: event.target.value || "gpt-4o-mini-transcribe" })
          }
        />
      </label>
      <label>
        <span>{provider === "azure-openai" ? "Azure endpoint" : "Endpoint"}</span>
        <input
          value={provider === "azure-openai" ? transcription.azureEndpoint ?? "" : transcription.baseUrl ?? "https://api.openai.com/v1"}
          onChange={(event) =>
            provider === "azure-openai"
              ? updateTranscription({ azureEndpoint: event.target.value })
              : updateTranscription({ baseUrl: event.target.value || "https://api.openai.com/v1" })
          }
        />
      </label>
      <label>
        <span>Deployment</span>
        <input
          value={transcription.azureDeployment ?? ""}
          disabled={provider !== "azure-openai"}
          onChange={(event) => updateTranscription({ azureDeployment: event.target.value })}
        />
      </label>
    </section>
  );
}

function preferredMimeType() {
  const types = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"];
  return types.find((type) => window.MediaRecorder?.isTypeSupported(type)) ?? "";
}

function viewStatusToVoiceButtonState(status: ViewStatus): VoiceButtonState {
  if (status === "listening") return "recording";
  if (status === "transcribing" || status === "running") return "processing";
  if (status === "failed") return "error";
  return "idle";
}

function statusToView(value: string): ViewStatus {
  if (value === "listening") return "listening";
  if (value === "transcribing") return "transcribing";
  if (value === "review") return "review";
  if (["running", "preparing", "queued", "verifying"].includes(value)) return "running";
  if (["failed", "needs-attention"].includes(value)) return "failed";
  return "ready";
}

function statusLabel(status: ViewStatus) {
  const labels: Record<ViewStatus, string> = {
    ready: "Ready",
    listening: "Listening",
    transcribing: "Transcribing",
    review: "Review",
    running: "Running",
    failed: "Needs attention"
  };
  return labels[status];
}

function voiceActionLabel(status: ViewStatus) {
  if (status === "listening") return "Recording";
  if (status === "transcribing") return "Transcribing";
  if (status === "running") return "Running";
  if (status === "failed") return "Retry voice";
  return "Test voice";
}

function providerLabel(value?: string) {
  const labels: Record<string, string> = {
    "azure-openai": "Azure",
    elevenlabs: "ElevenLabs",
    mock: "Mock",
    openai: "OpenAI",
    "openai-compatible": "Compatible"
  };
  return labels[value ?? "mock"] ?? value ?? "Mock";
}

function repoName(context: RepoContext, settings: WorkerflowSettings) {
  return context.repoRoot?.split("/").filter(Boolean).at(-1) ?? settings.activeRepo?.split("/").filter(Boolean).at(-1) ?? "repo";
}

function formatAgent(value: string) {
  return value === "claude" ? "Claude" : "Codex";
}

function createPreviewBridge(): WorkerflowBridge {
  let previewSettings: WorkerflowSettings = {
    ...initialSettings,
    activeRepo: "/Users/you/project"
  };
  const previewContext: RepoContext = {
    ...initialContext,
    repoRoot: previewSettings.activeRepo,
    branch: "main",
    changedFiles: ["apps/desktop/renderer/src/main.tsx", "apps/desktop/renderer/src/styles.css"],
    diffStat: "2 files changed",
    packageManager: "pnpm",
    projectFiles: ["package.json", "README.md"]
  };

  return {
    getSettings: async () => ({ settings: previewSettings, context: previewContext }),
    updateSettings: async (patch: Partial<WorkerflowSettings>) => {
      previewSettings = {
        ...previewSettings,
        ...patch,
        transcription: {
          ...previewSettings.transcription,
          ...patch.transcription
        }
      };
      return previewSettings;
    },
    chooseRepo: async () => ({ canceled: true, settings: previewSettings, context: previewContext }),
    interpretTask: async ({ task }: { task: string }) => ({
      task,
      transcript: task,
      mode: "action" as const,
      risk: task.toLowerCase().includes("deploy") ? ("high" as const) : ("low" as const),
      context: previewContext,
      settings: previewSettings
    }),
    requestMicrophoneAccess: async () => ({ ok: true, status: "granted" }),
    recordingFailed: async () => undefined,
    stopRecording: async () => undefined,
    sendAudio: async () => ({
      ok: true as const,
      transcript: "Fix the failing desktop tests and keep the patch small.",
      cleaned: "Fix the failing desktop tests and keep the patch small.",
      provider: "preview",
      settings: previewSettings
    }),
    runJob: async ({ task }: { task: string }) => ({
      ok: true,
      job: {
        id: "preview",
        status: "ready",
        agent: previewSettings.agent,
        task,
        summary: "Preview patch ready.",
        filesChanged: previewContext.changedFiles,
        verification: [{ name: "check", command: "pnpm check", code: 0 }]
      }
    }),
    openPath: async () => undefined,
    onOverlayStatus: () => () => undefined,
    onRecordingStart: () => () => undefined,
    onRecordingStop: () => () => undefined,
    onTaskReady: () => () => undefined,
    onTaskError: () => () => undefined,
    onJobStatus: () => () => undefined
  };
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
