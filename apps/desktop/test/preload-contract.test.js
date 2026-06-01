import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const preloadPath = path.resolve("src/preload.cjs");
const typesPath = path.resolve("renderer/src/types/workerflow.d.ts");

const requiredBridgeMethods = [
  "getSettings",
  "updateSettings",
  "chooseRepo",
  "interpretTask",
  "requestMicrophoneAccess",
  "recordingFailed",
  "stopRecording",
  "sendAudio",
  "runJob",
  "openPath",
  "onOverlayStatus",
  "onRecordingStart",
  "onRecordingStop",
  "onTaskReady",
  "onTaskError",
  "onJobStatus"
];

test("preload exposes every method in the renderer WorkerflowBridge contract", () => {
  const preload = fs.readFileSync(preloadPath, "utf8");
  const types = fs.readFileSync(typesPath, "utf8");

  for (const method of requiredBridgeMethods) {
    assert.match(preload, new RegExp(`\\b${method}\\s*:`), `${method} is missing from preload`);
    assert.match(types, new RegExp(`\\b${method}\\s*:`), `${method} is missing from WorkerflowBridge type`);
  }
});

test("preload listener APIs return unsubscribe functions", () => {
  const preload = fs.readFileSync(preloadPath, "utf8");

  for (const eventName of [
    "overlay:status",
    "recording:start",
    "recording:stop",
    "task:ready",
    "task:error",
    "job:status"
  ]) {
    const eventBlock = preload.slice(preload.indexOf(`ipcRenderer.on("${eventName}"`));
    assert.match(eventBlock, /return \(\) => ipcRenderer\.removeListener/, `${eventName} does not expose unsubscribe`);
  }
});
