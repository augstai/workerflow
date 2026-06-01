import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { captureRepoContext } from "./context.js";
import { environmentFiles } from "./env.js";
import { readProjectConfig } from "./config.js";
import { listJobs, workerflowHome } from "./jobs.js";

const MAX_COPIED_LOG_BYTES = 240_000;

export function workerflowLogDir() {
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Logs", "Workerflow");
  }

  return path.join(workerflowHome(), "logs");
}

export function nativeMacLogPath() {
  return path.join(workerflowLogDir(), "workerflow-mac.log");
}

export function diagnosticsRoot() {
  return path.join(workerflowHome(), "diagnostics");
}

export function createDiagnosticsBundle({
  cwd = process.cwd(),
  outputRoot = diagnosticsRoot(),
  loadedEnvFiles = [],
  jobs = listJobs(),
  now = new Date()
} = {}) {
  const stamp = now.toISOString().replace(/[:.]/g, "-");
  const bundleDir = path.join(outputRoot, `workerflow-diagnostics-${stamp}`);
  fs.mkdirSync(bundleDir, { recursive: true });

  const { config, path: configPath } = readProjectConfig(cwd);
  const context = captureRepoContext(cwd);
  const envFiles = environmentFiles(cwd).map((filePath) => ({
    path: filePath,
    exists: fs.existsSync(filePath),
    loaded: loadedEnvFiles.some((item) => item.path === filePath)
  }));

  const envPresence = Object.fromEntries(
    [
      "WORKERFLOW_REPO",
      "WORKERFLOW_TRANSCRIPTION_PROVIDER",
      "OPENAI_API_KEY",
      "AZURE_OPENAI_API_KEY",
      "AZURE_OPENAI_ENDPOINT",
      "AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT",
      "AZURE_OPENAI_API_VERSION",
      "ELEVENLABS_API_KEY",
      "ANTHROPIC_API_KEY"
    ].map((key) => [key, Boolean(process.env[key])])
  );

  const recentJobs = jobs.slice(0, 20).map((job) => ({
    id: job.id,
    status: job.status,
    agent: job.agent,
    repoRoot: job.repoRoot,
    branch: job.branch,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    finishedAt: job.finishedAt,
    artifactsDir: job.artifactsDir,
    summary: job.summary,
    error: job.error,
    filesChanged: job.filesChanged,
    diffStat: job.diffStat
  }));

  writeRedactedJson(path.join(bundleDir, "summary.json"), {
    createdAt: now.toISOString(),
    workerflowHome: workerflowHome(),
    cwd,
    platform: process.platform,
    arch: process.arch,
    node: process.version,
    pid: process.pid,
    configPath,
    config: config ?? null,
    context,
    envFiles,
    envPresence,
    logPaths: {
      nativeMac: nativeMacLogPath()
    }
  });

  writeRedactedText(path.join(bundleDir, "status.txt"), formatStatus({ context, configPath, config, envFiles, envPresence }));
  writeRedactedJson(path.join(bundleDir, "recent-jobs.json"), recentJobs);
  writeRecentJobArtifactIndex(bundleDir, recentJobs);
  copyLogIfPresent(nativeMacLogPath(), path.join(bundleDir, "workerflow-mac.log"));

  return {
    path: bundleDir,
    files: fs.readdirSync(bundleDir).sort()
  };
}

export function redactDiagnosticsText(input) {
  return String(input ?? "")
    .replace(/sk-(?:proj-)?[A-Za-z0-9_-]{12,}/g, "[REDACTED_OPENAI_KEY]")
    .replace(/AKIA[0-9A-Z]{16}/g, "[REDACTED_AWS_KEY]")
    .replace(
      /\b([A-Z0-9_]*(?:API_KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)[A-Z0-9_]*\s*[:=]\s*)(["']?)(?!set\b|missing\b|true\b|false\b|\[REDACTED\])([^"'\s,}]+)/gi,
      "$1$2[REDACTED]"
    )
    .replace(/\b(Authorization\s*:\s*Bearer\s+)[A-Za-z0-9._~+/-]+=*/gi, "$1[REDACTED]")
    .replace(/\b(x-api-key\s*:\s*)[A-Za-z0-9._~+/-]+=*/gi, "$1[REDACTED]");
}

function writeRecentJobArtifactIndex(bundleDir, recentJobs) {
  const lines = [];

  for (const job of recentJobs) {
    lines.push(`${job.id}  ${job.status}  ${job.artifactsDir || "no artifacts"}`);
    if (!job.artifactsDir || !fs.existsSync(job.artifactsDir)) continue;

    for (const file of fs.readdirSync(job.artifactsDir).sort()) {
      const fullPath = path.join(job.artifactsDir, file);
      const stat = fs.statSync(fullPath);
      lines.push(`  - ${file} (${stat.size} bytes)`);
    }
  }

  writeRedactedText(path.join(bundleDir, "recent-job-artifacts.txt"), `${lines.join("\n")}\n`);
}

function copyLogIfPresent(sourcePath, destinationPath) {
  if (!fs.existsSync(sourcePath)) return;

  const content = readTail(sourcePath, MAX_COPIED_LOG_BYTES);
  writeRedactedText(destinationPath, content);
}

function readTail(filePath, maxBytes) {
  const stat = fs.statSync(filePath);
  const bytesToRead = Math.min(stat.size, maxBytes);
  const buffer = Buffer.alloc(bytesToRead);
  const fd = fs.openSync(filePath, "r");

  try {
    fs.readSync(fd, buffer, 0, bytesToRead, Math.max(0, stat.size - bytesToRead));
  } finally {
    fs.closeSync(fd);
  }

  const prefix = stat.size > maxBytes ? `[truncated first ${stat.size - maxBytes} bytes]\n` : "";
  return `${prefix}${buffer.toString("utf8")}`;
}

function writeRedactedJson(filePath, value) {
  writeRedactedText(filePath, `${JSON.stringify(value, jsonRedactor, 2)}\n`);
}

function writeRedactedText(filePath, value) {
  fs.writeFileSync(filePath, redactDiagnosticsText(value));
}

function jsonRedactor(key, value) {
  if (/(api[_-]?key|token|secret|password|credential)/i.test(key)) {
    return value ? "[REDACTED]" : value;
  }
  return value;
}

function formatStatus({ context, configPath, config, envFiles, envPresence }) {
  return `Workerflow diagnostics

Repo: ${context.repoRoot}
Branch: ${context.branch || "unknown"}
Head: ${context.head || "unknown"}
Changed files: ${context.changedFiles.length}
Package manager: ${context.packageManager || "unknown"}
Config: ${configPath || "not attached"}
Agent: ${config?.agent || "codex"}
Transcription: ${config?.transcription?.provider || "mock"}
Native mac log: ${nativeMacLogPath()}

Env files:
${envFiles.map((item) => `- ${item.path} exists=${item.exists} loaded=${item.loaded}`).join("\n")}

Env presence:
${Object.entries(envPresence).map(([key, present]) => `- ${key}: ${present ? "set" : "missing"}`).join("\n")}
`;
}
