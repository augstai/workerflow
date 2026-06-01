#!/usr/bin/env node
import {
  buildAgentPrompt,
  captureRepoContext,
  commandExists,
  createJob,
  createDiagnosticsBundle,
  DEFAULT_CONFIG,
  diagnosticsRoot,
  formatSafetyRules,
  getJob,
  listJobs,
  loadEnvironment,
  nativeMacLogPath,
  readProjectConfig,
  runCommand,
  runWorkerflowJob,
  transcribeAudioFile,
  workerflowHome,
  writeProjectConfig
} from "../../../packages/core/src/index.js";

const args = process.argv.slice(2);
const command = args[0] ?? "help";
const rest = args.slice(1);
const loadedEnvFiles = loadEnvironment({ cwd: process.cwd() });

try {
  if (command === "attach") {
    attach(rest);
  } else if (command === "doctor") {
    await doctor(rest);
  } else if (command === "run") {
    await run(rest);
  } else if (command === "status") {
    status();
  } else if (command === "prompt") {
    prompt(rest);
  } else if (command === "transcribe") {
    await transcribe(rest);
  } else if (command === "job") {
    job(rest);
  } else if (command === "debug" || command === "diagnostics") {
    debug(rest);
  } else if (command === "safety") {
    safety();
  } else if (command === "help" || command === "--help" || command === "-h") {
    help();
  } else {
    fail(`Unknown command: ${command}`);
  }
} catch (error) {
  fail(error.message);
}

function attach(rawArgs) {
  const flags = parseFlags(rawArgs);
  const existing = readProjectConfig(process.cwd()).config ?? {};
  const config = {
    ...DEFAULT_CONFIG,
    ...existing,
    agent: flags.agent ?? existing.agent ?? DEFAULT_CONFIG.agent,
    commands: {
      ...DEFAULT_CONFIG.commands,
      ...(existing.commands ?? {}),
      test: flags.test ?? existing.commands?.test ?? DEFAULT_CONFIG.commands.test,
      build: flags.build ?? existing.commands?.build ?? DEFAULT_CONFIG.commands.build,
      lint: flags.lint ?? existing.commands?.lint ?? DEFAULT_CONFIG.commands.lint
    },
    worktree: flags.worktree ?? existing.worktree ?? DEFAULT_CONFIG.worktree
  };

  if (flags.hotkey) {
    config.desktop = {
      ...config.desktop,
      hotkey: flags.hotkey
    };
  }

  if (flags.transcription) {
    config.transcription = {
      ...config.transcription,
      provider: flags.transcription
    };
  }

  const { path } = writeProjectConfig(process.cwd(), config);

  console.log(`Workerflow attached: ${path}`);
  console.log(`Agent: ${config.agent}`);
  console.log(`Hotkey: ${config.desktop.hotkey}`);
  console.log(`Transcription: ${config.transcription.provider}`);
  console.log(`Worktree: ${config.worktree ? "enabled" : "disabled"}`);
  printCommand("test", config.commands.test);
  printCommand("build", config.commands.build);
  printCommand("lint", config.commands.lint);
}

async function doctor(rawArgs) {
  const flags = parseFlags(rawArgs);
  const { config, path } = readProjectConfig(process.cwd());
  const context = captureRepoContext(process.cwd());
  const checks = [
    ["git", commandExists("git")],
    ["codex", commandExists("codex")],
    ["claude", commandExists("claude")]
  ];

  console.log("Workerflow doctor");
  console.log("");
  console.log(`Repo: ${context.repoRoot}`);
  console.log(`Branch: ${context.branch || "unknown"}`);
  console.log(`Config: ${path ?? "not attached"}`);
  console.log(`Agent: ${(config ?? DEFAULT_CONFIG).agent}`);
  console.log(`Hotkey: ${(config ?? DEFAULT_CONFIG).desktop.hotkey}`);
  console.log(`Env files: ${loadedEnvFiles.length ? loadedEnvFiles.map((item) => item.path).join(", ") : "none"}`);
  console.log("");

  for (const [name, result] of checks) {
    console.log(`${result.ok ? "ok" : "missing"}  ${name}${result.path ? `  ${result.path}` : ""}`);
  }

  if (flags["smoke-codex"]) {
    await smokeAgent(
      "codex",
      ["--ask-for-approval", "never", "exec", "--cd", process.cwd(), "--sandbox", "read-only", "--color", "never", "-"],
      "Say exactly: workerflow-codex-ok"
    );
  }

  if (flags["smoke-claude"]) {
    await smokeAgent(
      "claude",
      ["-p", "--permission-mode", "dontAsk", "--output-format", "text", "--no-session-persistence", "Say exactly: workerflow-claude-ok"],
      ""
    );
  }

  const activeConfig = config ?? DEFAULT_CONFIG;
  console.log("");
  printCommand("test", activeConfig.commands?.test);
  printCommand("build", activeConfig.commands?.build);
  printCommand("lint", activeConfig.commands?.lint);
}

async function smokeAgent(name, args, input) {
  console.log("");
  console.log(`Smoke: ${name}`);
  const result = await runCommand({
    command: name,
    args,
    cwd: process.cwd(),
    input,
    timeoutMs: 20000
  });

  const output = `${result.stdout}${result.stderr}`.trim();
  console.log(`${result.code === 0 ? "ok" : "failed"}  exit=${result.code}${result.timedOut ? " timed-out" : ""}`);
  if (output) {
    console.log(output.split("\n").slice(0, 6).join("\n"));
  }
}

async function run(rawArgs) {
  const flags = parseFlags(rawArgs);
  const task = rawArgs.filter((value, index) => {
    if (!value.startsWith("--")) {
      return rawArgs[index - 1] !== "--agent";
    }
    return false;
  }).join(" ").trim();

  if (!task) {
    fail("Usage: workerflow run [--agent codex|claude] [--dry-run] <task>");
  }

  const job = await runWorkerflowJob({
    task,
    cwd: process.cwd(),
    agent: flags.agent,
    dryRun: Boolean(flags["dry-run"])
  });

  console.log(`Job: ${job.id}`);
  console.log(`Status: ${job.status}`);
  console.log(`Agent: ${job.agent}`);
  if (job.workspaceDir) {
    console.log(`Workspace: ${job.workspaceDir}`);
  }
  if (job.summary) {
    console.log(`Summary: ${job.summary}`);
  }
  if (job.artifactsDir) {
    console.log(`Artifacts: ${job.artifactsDir}`);
  }
}

function status() {
  const { config, path } = readProjectConfig(process.cwd());
  const context = captureRepoContext(process.cwd());
  const effectiveConfig = config ?? DEFAULT_CONFIG;

  console.log("Workerflow status");
  console.log("");
  console.log(`Config: ${path ?? "not attached"}`);
  console.log(`Repo: ${context.repoRoot}`);
  console.log(`Branch: ${context.branch ?? "unknown"}`);
  console.log(`Package manager: ${context.packageManager ?? "unknown"}`);
  console.log(`Changed files: ${context.changedFiles.length}`);
  console.log(`Diff stat: ${context.diffStat || "clean"}`);

  if (config) {
    console.log("");
    console.log(`Agent: ${effectiveConfig.agent}`);
    console.log(`Hotkey: ${effectiveConfig.desktop?.hotkey ?? DEFAULT_CONFIG.desktop.hotkey}`);
    console.log(`Transcription: ${effectiveTranscriptionProvider(effectiveConfig)}`);
    console.log(`Worktree: ${effectiveConfig.worktree ? "enabled" : "disabled"}`);
    printCommand("test", effectiveConfig.commands?.test);
    printCommand("build", effectiveConfig.commands?.build);
    printCommand("lint", effectiveConfig.commands?.lint);
  }
}

async function transcribe(rawArgs) {
  const filePath = rawArgs[0];
  if (!filePath) {
    fail("Usage: workerflow transcribe <audio-file>");
  }

  const { config } = readProjectConfig(process.cwd());
  const result = await transcribeAudioFile({
    filePath,
    config: config ?? DEFAULT_CONFIG
  });

  console.log(result.cleaned || result.transcript);
}

function effectiveTranscriptionProvider(config) {
  return process.env.WORKERFLOW_TRANSCRIPTION_PROVIDER
    || config.transcription?.provider
    || DEFAULT_CONFIG.transcription.provider;
}

function prompt(rawArgs) {
  const task = rawArgs.join(" ").trim();
  if (!task) {
    fail("Usage: workerflow prompt <task>");
  }

  const { config } = readProjectConfig(process.cwd());
  const context = captureRepoContext(process.cwd());

  console.log(
    buildAgentPrompt({
      task,
      config: config ?? DEFAULT_CONFIG,
      context
    })
  );
}

function job(rawArgs) {
  const subcommand = rawArgs[0] ?? "list";
  const subArgs = rawArgs.slice(1);

  if (subcommand === "list") {
    const jobs = listJobs();
    if (jobs.length === 0) {
      console.log("No Workerflow jobs yet.");
      return;
    }

    for (const item of jobs) {
      console.log(`${item.id}  ${item.status}  ${item.task}`);
    }
    return;
  }

  if (subcommand === "show") {
    const id = subArgs[0];
    if (!id) {
      fail("Usage: workerflow job show <job-id>");
    }

    const record = getJob(id);
    if (!record) {
      fail(`Unknown job: ${id}`);
    }

    console.log(JSON.stringify(record, null, 2));
    return;
  }

  if (subcommand === "create") {
    const task = subArgs.join(" ").trim();
    if (!task) {
      fail("Usage: workerflow job create <task>");
    }

    const { config } = readProjectConfig(process.cwd());
    const context = captureRepoContext(process.cwd());
    const record = createJob({
      task,
      repoRoot: context.repoRoot,
      branch: context.branch,
      agent: config?.agent ?? DEFAULT_CONFIG.agent,
      prompt: buildAgentPrompt({
        task,
        config: config ?? DEFAULT_CONFIG,
        context
      })
    });

    console.log(`Created job ${record.id}`);
    console.log(`Status: ${record.status}`);
    return;
  }

  fail(`Unknown job command: ${subcommand}`);
}

function safety() {
  console.log(formatSafetyRules());
}

function debug(rawArgs) {
  const flags = parseFlags(rawArgs);

  if (flags.bundle) {
    const bundle = createDiagnosticsBundle({
      cwd: process.cwd(),
      loadedEnvFiles
    });
    console.log(`Bundle: ${bundle.path}`);
    for (const file of bundle.files) {
      console.log(`- ${file}`);
    }
    return;
  }

  const { config, path } = readProjectConfig(process.cwd());
  const context = captureRepoContext(process.cwd());

  console.log("Workerflow debug");
  console.log("");
  console.log(`Repo: ${context.repoRoot}`);
  console.log(`Config: ${path ?? "not attached"}`);
  console.log(`Agent: ${(config ?? DEFAULT_CONFIG).agent}`);
  console.log(`Transcription: ${(config ?? DEFAULT_CONFIG).transcription.provider}`);
  console.log(`Workerflow home: ${workerflowHome()}`);
  console.log(`Native Mac log: ${nativeMacLogPath()}`);
  console.log(`Diagnostics dir: ${diagnosticsRoot()}`);
  console.log(`Env files: ${loadedEnvFiles.length ? loadedEnvFiles.map((item) => item.path).join(", ") : "none loaded"}`);
  console.log("");
  console.log("Create a redacted diagnostics bundle with:");
  console.log("workerflow debug --bundle");
}

function help() {
  console.log(`Workerflow

Usage:
  workerflow attach [--agent codex] [--test "pnpm test"] [--build "..."] [--lint "..."] [--no-worktree]
  workerflow doctor [--smoke-codex] [--smoke-claude]
  workerflow status
  workerflow prompt <task>
  workerflow transcribe <audio-file>
  workerflow run [--agent codex|claude] [--dry-run] <task>
  workerflow job list
  workerflow job show <job-id>
  workerflow job create <task>
  workerflow debug [--bundle]
  workerflow safety
`);
}

function parseFlags(rawArgs) {
  const flags = {};

  for (let index = 0; index < rawArgs.length; index += 1) {
    const value = rawArgs[index];
    if (value === "--no-worktree") {
      flags.worktree = false;
      continue;
    }

    if (!value.startsWith("--")) {
      continue;
    }

    const key = value.slice(2);
    const next = rawArgs[index + 1];
    if (!next || next.startsWith("--")) {
      flags[key] = true;
    } else {
      flags[key] = next;
      index += 1;
    }
  }

  return flags;
}

function printCommand(label, value) {
  if (value) {
    console.log(`${label}: ${value}`);
  }
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
