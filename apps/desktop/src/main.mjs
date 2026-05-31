import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import {
  app,
  BrowserWindow,
  globalShortcut,
  ipcMain,
  Menu,
  nativeImage,
  Notification,
  screen,
  shell,
  Tray
} from "electron";
import {
  classifyTask,
  DEFAULT_CONFIG,
  runWorkerflowJob,
  transcribeAudioFile,
  workerflowHome
} from "../../../packages/core/src/index.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const settingsPath = path.join(workerflowHome(), "settings.json");

let tray;
let overlayWindow;
let settings;
let recording = false;
let helperProcess;

app.setName("Workerflow");

app.whenReady().then(() => {
  settings = readSettings();
  createTray();
  createOverlayWindow();
  registerHotkey();
  app.dock?.hide();
});

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
  helperProcess?.kill();
});

ipcMain.handle("settings:get", () => settings);

ipcMain.handle("settings:update", (_event, patch) => {
  settings = writeSettings({
    ...settings,
    ...patch
  });
  registerHotkey();
  updateTrayMenu();
  return settings;
});

ipcMain.handle("recording:failed", () => {
  recording = false;
});

ipcMain.handle("recording:stop-request", () => {
  stopRecording();
});

ipcMain.handle("recording:audio", async (_event, payload) => {
  const audioPath = path.join(workerflowHome(), "last-recording.webm");
  fs.mkdirSync(workerflowHome(), { recursive: true });
  fs.writeFileSync(audioPath, Buffer.from(payload));

  try {
    const result = await transcribeAudioFile({
      filePath: audioPath,
      config: {
        ...DEFAULT_CONFIG,
        transcription: settings.transcription
      },
      prompt: "A developer is speaking a short coding-agent command."
    });
    const interpreted = classifyTask(result.cleaned || result.transcript);
    overlayWindow.webContents.send("task:ready", {
      transcript: result.transcript,
      task: interpreted.task,
      mode: interpreted.mode,
      risk: interpreted.risk
    });
  } catch (error) {
    overlayWindow.webContents.send("task:error", {
      message: error.message
    });
  }
});

ipcMain.handle("job:run", async (_event, payload) => {
  const task = payload.task?.trim();
  if (!task) {
    return { ok: false, error: "No task provided." };
  }

  overlayWindow.webContents.send("job:status", {
    status: "running",
    message: "Running agent"
  });

  const job = await runWorkerflowJob({
    task,
    cwd: settings.activeRepo,
    agent: settings.agent
  });

  overlayWindow.webContents.send("job:status", {
    status: job.status,
    message: job.summary ?? job.status,
    job
  });

  if (Notification.isSupported()) {
    new Notification({
      title: job.status === "ready" ? "Patch ready" : "Workerflow job finished",
      body: job.summary ?? `${job.agent} finished with ${job.status}.`
    }).show();
  }

  return { ok: true, job };
});

ipcMain.handle("system:openPath", (_event, targetPath) => {
  if (targetPath) {
    shell.openPath(targetPath);
  }
});

function createOverlayWindow() {
  overlayWindow = new BrowserWindow({
    width: 460,
    height: 320,
    show: false,
    frame: false,
    transparent: true,
    resizable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  overlayWindow.loadFile(path.join(__dirname, "overlay.html"));
  overlayWindow.on("blur", () => {
    if (!recording) {
      overlayWindow.hide();
    }
  });
}

function createTray() {
  tray = new Tray(createTrayIcon());
  tray.setToolTip("Workerflow");
  tray.on("click", () => showOverlay("ready"));
  updateTrayMenu();
}

function updateTrayMenu() {
  const menu = Menu.buildFromTemplate([
    {
      label: `Workerflow: ${settings.agent}`,
      enabled: false
    },
    {
      label: `Hotkey: ${settings.hotkey}`,
      enabled: false
    },
    {
      label: "Show",
      click: () => showOverlay("ready")
    },
    {
      label: "Quit",
      click: () => app.quit()
    }
  ]);
  tray.setContextMenu(menu);
}

function registerHotkey() {
  globalShortcut.unregisterAll();
  helperProcess?.kill();
  helperProcess = null;

  if (settings.hotkeyMode === "hold" && startMacHotkeyHelper()) {
    return;
  }

  const ok = globalShortcut.register(settings.hotkey, () => {
    if (recording) {
      stopRecording();
    } else {
      startRecording();
    }
  });

  if (!ok) {
    console.error(`Failed to register hotkey: ${settings.hotkey}`);
  }
}

function startMacHotkeyHelper() {
  if (process.platform !== "darwin") {
    return false;
  }

  const helperPath = path.join(__dirname, "../native/build/workerflow-hotkey");
  if (!fs.existsSync(helperPath)) {
    return false;
  }

  helperProcess = spawn(helperPath, [], {
    stdio: ["ignore", "pipe", "pipe"]
  });

  helperProcess.stdout.on("data", (chunk) => {
    for (const line of chunk.toString().split("\n").filter(Boolean)) {
      try {
        const event = JSON.parse(line);
        if (event.type === "hotkey-down" && !recording) startRecording();
        if (event.type === "hotkey-up" && recording) stopRecording();
      } catch {
        // Ignore malformed helper output.
      }
    }
  });

  helperProcess.on("exit", () => {
    helperProcess = null;
    if (settings.hotkeyMode === "hold") {
      settings = writeSettings({
        ...settings,
        hotkeyMode: "toggle"
      });
      updateTrayMenu();
    }
    registerHotkey();
  });

  return true;
}

function startRecording() {
  recording = true;
  showOverlay("listening");
  overlayWindow.webContents.send("recording:start");
}

function stopRecording() {
  recording = false;
  overlayWindow.webContents.send("recording:stop");
}

function showOverlay(status) {
  const display = overlayWindow.getBounds();
  const workArea = screen.getPrimaryDisplay().workArea;
  overlayWindow.setPosition(
    Math.round(workArea.x + workArea.width / 2 - display.width / 2),
    Math.round(workArea.y + 52)
  );
  overlayWindow.showInactive();
  overlayWindow.webContents.send("overlay:status", {
    status,
    settings
  });
}

function createTrayIcon() {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
    <rect width="32" height="32" rx="8" fill="#111827"/>
    <path d="M9 10h4l2 8 3-12 2 14 2-10h3" fill="none" stroke="#34d399" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
  </svg>`;
  return nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`);
}

function readSettings() {
  if (fs.existsSync(settingsPath)) {
    return {
      ...defaultSettings(),
      ...JSON.parse(fs.readFileSync(settingsPath, "utf8"))
    };
  }
  return writeSettings(defaultSettings());
}

function writeSettings(next) {
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, `${JSON.stringify(next, null, 2)}\n`);
  return next;
}

function defaultSettings() {
  return {
    activeRepo: process.env.WORKERFLOW_REPO || process.cwd(),
    agent: "codex",
    hotkey: "Alt+Space",
    hotkeyMode: "toggle",
    transcription: {
      provider: "mock",
      model: "gpt-4o-mini-transcribe"
    }
  };
}
