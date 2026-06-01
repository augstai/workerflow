import type { RepoContext, TaskPayload, WorkerflowSettings } from "./types/workerflow";
import type { VoiceButtonState } from "./components/elevenlabs-ui/voice-button";

export type ViewStatus = "ready" | "listening" | "transcribing" | "review" | "running" | "failed";

export function viewStatusToVoiceButtonState(status: ViewStatus): VoiceButtonState;
export function statusToView(value: string): ViewStatus;
export function statusLabel(status: ViewStatus): string;
export function statusSubtitle(status: ViewStatus, settings: WorkerflowSettings, repo: string): string;
export function voiceActionLabel(status: ViewStatus): string;
export function providerLabel(value?: string): string;
export function repoName(context: RepoContext, settings: WorkerflowSettings): string;
export function formatAgent(value: string): string;
export function canRunTask(confirmation: TaskPayload | null, task: string): boolean;
