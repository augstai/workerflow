import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import {
  app,
  BrowserWindow,
  dialog,
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
  captureRepoContext,
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
let keepOverlayVisibleUntil = 0;

app.setName("Workerflow");

app.whenReady().then(() => {
  settings = readSettings();
  createTray();
  createOverlayWindow();
  registerHotkey();
  app.dock?.hide();
  console.log(`Workerflow desktop ready. Hotkey: ${displayHotkey(settings.hotkey)}. Tray: active.`);
});

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
  helperProcess?.kill();
});

ipcMain.handle("settings:get", () => ({
  settings: viewSettings(settings),
  context: safeRepoContext(settings.activeRepo)
}));

ipcMain.handle("settings:update", (_event, patch) => {
  settings = writeSettings(mergeSettings(settings, patch));
  registerHotkey();
  updateTrayMenu();
  return viewSettings(settings);
});

ipcMain.handle("repo:choose", async () => {
  const result = await dialog.showOpenDialog(overlayWindow, {
    defaultPath: settings.activeRepo,
    properties: ["openDirectory"]
  });

  if (result.canceled || !result.filePaths[0]) {
    return { canceled: true, settings: viewSettings(settings) };
  }

  settings = writeSettings({
    ...settings,
    activeRepo: result.filePaths[0]
  });
  updateTrayMenu();
  return {
    canceled: false,
    settings: viewSettings(settings),
    context: safeRepoContext(settings.activeRepo)
  };
});

ipcMain.handle("task:interpret", (_event, payload) => {
  const interpreted = classifyTask(payload.task ?? "");
  return {
    ...interpreted,
    context: safeRepoContext(settings.activeRepo),
    settings: viewSettings(settings)
  };
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
      risk: interpreted.risk,
      context: safeRepoContext(settings.activeRepo)
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
    agent: settings.agent,
    onStatus: (status) => {
      overlayWindow.webContents.send("job:status", status);
    }
  });

  overlayWindow.webContents.send("job:status", {
    status: job.status,
    message: job.summary ?? job.status,
    job,
    context: safeRepoContext(settings.activeRepo)
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
    width: 560,
    height: 620,
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
  overlayWindow.webContents.once("did-finish-load", () => {
    if (process.env.WORKERFLOW_SHOW_ON_START !== "0") {
      showOverlay("ready", { pinMs: 3000 });
    }
  });
  overlayWindow.on("blur", () => {
    if (!recording && Date.now() > keepOverlayVisibleUntil) {
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
      label: `Workerflow: ${formatAgent(settings.agent)}`,
      enabled: false
    },
    {
      label: `Hotkey: ${displayHotkey(settings.hotkey)}`,
      enabled: false
    },
    {
      label: `Repo: ${path.basename(settings.activeRepo)}`,
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

function showOverlay(status, options = {}) {
  if (options.pinMs) {
    keepOverlayVisibleUntil = Date.now() + options.pinMs;
  }

  const display = overlayWindow.getBounds();
  const workArea = screen.getPrimaryDisplay().workArea;
  overlayWindow.setPosition(
    Math.round(workArea.x + workArea.width / 2 - display.width / 2),
    Math.round(workArea.y + 52)
  );
  overlayWindow.showInactive();
  overlayWindow.webContents.send("overlay:status", {
    status,
    settings: viewSettings(settings),
    context: safeRepoContext(settings.activeRepo)
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
    return mergeSettings(defaultSettings(), JSON.parse(fs.readFileSync(settingsPath, "utf8")));
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
      model: "gpt-4o-mini-transcribe",
      apiKeyEnv: "OPENAI_API_KEY",
      baseUrl: "https://api.openai.com/v1",
      azureEndpoint: "",
      azureDeployment: "",
      azureApiVersion: "2024-06-01-preview",
      azureApiKeyEnv: "AZURE_OPENAI_API_KEY",
      elevenLabsApiKeyEnv: "ELEVENLABS_API_KEY",
      elevenLabsModel: "scribe_v2"
    }
  };
}

function mergeSettings(base, patch) {
  return {
    ...base,
    ...patch,
    transcription: {
      ...(base.transcription ?? {}),
      ...(patch.transcription ?? {})
    }
  };
}

function viewSettings(value) {
  return {
    ...value,
    hotkeyLabel: displayHotkey(value.hotkey),
    agentLabel: formatAgent(value.agent)
  };
}

function safeRepoContext(repoPath) {
  try {
    return captureRepoContext(repoPath);
  } catch (error) {
    return {
      repoRoot: repoPath,
      branch: "",
      changedFiles: [],
      diffStat: "",
      packageManager: "",
      projectFiles: [],
      error: error.message
    };
  }
}

function displayHotkey(value) {
  if (process.platform !== "darwin") {
    return value;
  }
  return value.replace(/\bAlt\b/g, "Option").replace(/\bCmd\b/g, "Command").replace(/\bCtrl\b/g, "Control");
}

function formatAgent(value) {
  return value === "claude" ? "Claude" : "Codex";
}
