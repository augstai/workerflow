const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("workerflow", {
  getSettings: () => ipcRenderer.invoke("settings:get"),
  updateSettings: (patch) => ipcRenderer.invoke("settings:update", patch),
  recordingFailed: () => ipcRenderer.invoke("recording:failed"),
  stopRecording: () => ipcRenderer.invoke("recording:stop-request"),
  sendAudio: (buffer) => ipcRenderer.invoke("recording:audio", buffer),
  runJob: (payload) => ipcRenderer.invoke("job:run", payload),
  openPath: (targetPath) => ipcRenderer.invoke("system:openPath", targetPath),
  onOverlayStatus: (callback) => ipcRenderer.on("overlay:status", (_event, payload) => callback(payload)),
  onRecordingStart: (callback) => ipcRenderer.on("recording:start", callback),
  onRecordingStop: (callback) => ipcRenderer.on("recording:stop", callback),
  onTaskReady: (callback) => ipcRenderer.on("task:ready", (_event, payload) => callback(payload)),
  onTaskError: (callback) => ipcRenderer.on("task:error", (_event, payload) => callback(payload)),
  onJobStatus: (callback) => ipcRenderer.on("job:status", (_event, payload) => callback(payload))
});
