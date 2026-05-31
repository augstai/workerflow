const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("workerflow", {
  getSettings: () => ipcRenderer.invoke("settings:get"),
  updateSettings: (patch) => ipcRenderer.invoke("settings:update", patch),
  chooseRepo: () => ipcRenderer.invoke("repo:choose"),
  interpretTask: (payload) => ipcRenderer.invoke("task:interpret", payload),
  requestMicrophoneAccess: () => ipcRenderer.invoke("permissions:microphone"),
  recordingFailed: () => ipcRenderer.invoke("recording:failed"),
  stopRecording: () => ipcRenderer.invoke("recording:stop-request"),
  sendAudio: (payload) => ipcRenderer.invoke("recording:audio", payload),
  runJob: (payload) => ipcRenderer.invoke("job:run", payload),
  openPath: (targetPath) => ipcRenderer.invoke("system:openPath", targetPath),
  onOverlayStatus: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("overlay:status", listener);
    return () => ipcRenderer.removeListener("overlay:status", listener);
  },
  onRecordingStart: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("recording:start", listener);
    return () => ipcRenderer.removeListener("recording:start", listener);
  },
  onRecordingStop: (callback) => {
    const listener = () => callback();
    ipcRenderer.on("recording:stop", listener);
    return () => ipcRenderer.removeListener("recording:stop", listener);
  },
  onTaskReady: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("task:ready", listener);
    return () => ipcRenderer.removeListener("task:ready", listener);
  },
  onTaskError: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("task:error", listener);
    return () => ipcRenderer.removeListener("task:error", listener);
  },
  onJobStatus: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on("job:status", listener);
    return () => ipcRenderer.removeListener("job:status", listener);
  }
});
