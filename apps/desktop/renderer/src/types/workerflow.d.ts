export type WorkerflowSettings = {
  activeRepo: string;
  agent: "codex" | "claude";
  agentLabel: string;
  hotkey: string;
  hotkeyLabel: string;
  hotkeyMode: "toggle" | "hold";
  transcription: {
    provider: string;
    model?: string;
    apiKeyEnv?: string;
    baseUrl?: string;
    azureEndpoint?: string;
    azureDeployment?: string;
    azureApiVersion?: string;
    azureApiKeyEnv?: string;
    elevenLabsApiKeyEnv?: string;
    elevenLabsModel?: string;
  };
};

export type RepoContext = {
  repoRoot: string;
  branch: string;
  changedFiles: string[];
  diffStat: string;
  packageManager: string;
  projectFiles: string[];
  error?: string;
};

export type TaskPayload = {
  transcript?: string;
  task: string;
  mode: "action" | "dictation";
  risk: "low" | "medium" | "high";
  context?: RepoContext;
  settings?: WorkerflowSettings;
};

export type WorkerflowJob = {
  id: string;
  status: string;
  agent: string;
  task: string;
  summary?: string;
  artifactsDir?: string;
  filesChanged?: string[];
  verification?: Array<{
    name: string;
    command: string;
    code: number;
  }>;
};

export type VoiceTestResponse =
  | {
      ok: true;
      transcript: string;
      cleaned: string;
      provider: string;
      settings: WorkerflowSettings;
    }
  | {
      ok: false;
      error: string;
    };

type Unsubscribe = () => void;

export type WorkerflowBridge = {
  getSettings: () => Promise<{ settings: WorkerflowSettings; context: RepoContext }>;
  updateSettings: (patch: Partial<WorkerflowSettings>) => Promise<WorkerflowSettings>;
  chooseRepo: () => Promise<{ canceled: boolean; settings: WorkerflowSettings; context?: RepoContext }>;
  interpretTask: (payload: { task: string }) => Promise<TaskPayload>;
  requestMicrophoneAccess: () => Promise<{ ok: boolean; status: string }>;
  recordingFailed: () => Promise<void>;
  stopRecording: () => Promise<void>;
  sendAudio: (payload: { buffer: ArrayBuffer; mode: "task" | "test" }) => Promise<VoiceTestResponse | { ok: boolean; error?: string }>;
  runJob: (payload: { task: string }) => Promise<{ ok: boolean; error?: string; job?: WorkerflowJob }>;
  openPath: (targetPath: string) => Promise<void>;
  onOverlayStatus: (callback: (payload: { status: string; settings: WorkerflowSettings; context: RepoContext }) => void) => Unsubscribe;
  onRecordingStart: (callback: (payload?: { mode?: "task" | "test" }) => void) => Unsubscribe;
  onRecordingStop: (callback: () => void) => Unsubscribe;
  onTaskReady: (callback: (payload: TaskPayload) => void) => Unsubscribe;
  onTaskError: (callback: (payload: { message: string }) => void) => Unsubscribe;
  onJobStatus: (callback: (payload: { status: string; message?: string; job?: WorkerflowJob; context?: RepoContext }) => void) => Unsubscribe;
};

declare global {
  interface Window {
    workerflow?: WorkerflowBridge;
  }
}
