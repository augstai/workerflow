import assert from "node:assert/strict";
import test from "node:test";
import {
  canRunTask,
  formatAgent,
  providerLabel,
  repoName,
  statusLabel,
  statusSubtitle,
  statusToView,
  viewStatusToVoiceButtonState,
  voiceActionLabel
} from "../renderer/src/app-logic.js";

const settings = {
  activeRepo: "/Users/me/project",
  agent: "codex",
  agentLabel: "Codex",
  hotkey: "Alt+Space",
  hotkeyLabel: "Option+Space",
  hotkeyMode: "toggle",
  transcription: {
    provider: "mock"
  }
};

test("statusToView maps workerflow lifecycle statuses to renderer views", () => {
  assert.equal(statusToView("queued"), "running");
  assert.equal(statusToView("preparing"), "running");
  assert.equal(statusToView("verifying"), "running");
  assert.equal(statusToView("needs-attention"), "failed");
  assert.equal(statusToView("review"), "review");
  assert.equal(statusToView("unknown"), "ready");
});

test("viewStatusToVoiceButtonState maps renderer state to voice button state", () => {
  assert.equal(viewStatusToVoiceButtonState("listening"), "recording");
  assert.equal(viewStatusToVoiceButtonState("transcribing"), "processing");
  assert.equal(viewStatusToVoiceButtonState("running"), "processing");
  assert.equal(viewStatusToVoiceButtonState("failed"), "error");
  assert.equal(viewStatusToVoiceButtonState("ready"), "idle");
});

test("providerLabel and formatAgent keep user-facing labels stable", () => {
  assert.equal(providerLabel("azure-openai"), "Azure");
  assert.equal(providerLabel("elevenlabs"), "ElevenLabs");
  assert.equal(providerLabel("openai-compatible"), "Compatible");
  assert.equal(providerLabel("custom-provider"), "custom-provider");
  assert.equal(formatAgent("claude"), "Claude");
  assert.equal(formatAgent("codex"), "Codex");
});

test("status labels and subtitles cover active states", () => {
  assert.equal(statusLabel("failed"), "Needs attention");
  assert.equal(statusSubtitle("listening", settings, "workerflow"), "Recording for workerflow");
  assert.equal(statusSubtitle("running", settings, "workerflow"), "Codex is working");
  assert.equal(statusSubtitle("ready", settings, "workerflow"), "Codex -> workerflow");
  assert.equal(voiceActionLabel("failed"), "Try again");
});

test("repoName falls back from context to settings", () => {
  assert.equal(repoName({ repoRoot: "/tmp/workerflow" }, settings), "workerflow");
  assert.equal(repoName({ repoRoot: "" }, settings), "project");
});

test("canRunTask blocks dictation and empty tasks", () => {
  assert.equal(canRunTask(null, ""), false);
  assert.equal(canRunTask(null, "Fix tests"), true);
  assert.equal(canRunTask({ task: "Write this", mode: "dictation" }, ""), false);
  assert.equal(canRunTask({ task: "Fix this", mode: "action" }, ""), true);
});
