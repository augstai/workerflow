import fs from "node:fs";
import path from "node:path";
import { buildAdapterInvocation, normalizeAgent } from "./adapters.js";
import { runCommand, runShellCommand } from "./commands.js";
import { captureRepoContext } from "./context.js";
import { DEFAULT_CONFIG, readProjectConfig } from "./config.js";
import { createJob, updateJob } from "./jobs.js";
import { buildAgentPrompt } from "./prompt.js";
import { captureDiff, createWorktree } from "./worktree.js";

export async function runWorkerflowJob({
  task,
  cwd,
  agent,
  dryRun = false,
  screenContextDir,
  onStatus,
  dependencies = {}
}) {
  const {
    commandRunner = runCommand,
    shellCommandRunner = runShellCommand,
    createWorktreeFn = createWorktree,
    captureDiffFn = captureDiff
  } = dependencies;
  const { config: projectConfig } = readProjectConfig(cwd);
  const config = projectConfig ?? DEFAULT_CONFIG;
  const selectedAgent = normalizeAgent(agent ?? config.agent);
  const context = captureRepoContext(cwd);
  const screenContext = loadScreenContext(screenContextDir);
  const prompt = buildAgentPrompt({
    task,
    config: {
      ...config,
      agent: selectedAgent
    },
    context,
    screenContext
  });

  let job = createJob({
    task,
    repoRoot: context.repoRoot,
    branch: context.branch,
    agent: selectedAgent,
    prompt
  });

  writeArtifact(job, "prompt.md", prompt);
  if (screenContextDir) {
    copyScreenContextArtifacts(job, screenContextDir);
  }
  onStatus?.({
    status: "queued",
    message: "Job queued",
    job
  });

  if (dryRun) {
    return updateJob(job.id, {
      status: "dry-run",
      workspaceDir: context.repoRoot,
      summary: "Dry run created prompt and job metadata without invoking an agent."
    });
  }

  try {
    job = updateJob(job.id, { status: "preparing" });
    onStatus?.({
      status: "preparing",
      message: "Preparing isolated workspace",
      job
    });
    const workspace = config.worktree
      ? createWorktreeFn({ repoRoot: context.repoRoot, jobId: job.id })
      : { path: context.repoRoot, branch: context.branch };

    job = updateJob(job.id, {
      status: "running",
      workspaceDir: workspace.path,
      worktreeBranch: workspace.branch
    });
    onStatus?.({
      status: "running",
      message: `Running ${selectedAgent}`,
      job
    });

    const resultPath = path.join(job.artifactsDir, "agent-result.md");
    const invocation = buildAdapterInvocation({
      agent: selectedAgent,
      config,
      workspaceDir: workspace.path,
      resultPath
    });
    const adapterConfig = config.adapters?.[selectedAgent] ?? {};

    const agentResult = await commandRunner({
      command: invocation.command,
      args: invocation.args,
      cwd: workspace.path,
      input: invocation.stdin ? prompt : undefined,
      timeoutMs: adapterConfig.timeoutMs
    });
    writeArtifact(job, "agent-stdout.log", agentResult.stdout);
    writeArtifact(job, "agent-stderr.log", agentResult.stderr);

    onStatus?.({
      status: "verifying",
      message: "Running verification",
      job
    });
    const verification = await runVerificationCommands(config, workspace.path, shellCommandRunner);
    writeArtifact(job, "verification.json", JSON.stringify(verification, null, 2));

    const diff = captureDiffFn(workspace.path);
    writeArtifact(job, "diff.patch", diff.patch);
    writeArtifact(job, "diff-stat.txt", diff.stat);

    const resultText = readIfExists(resultPath) || agentResult.stdout.trim() || agentResult.stderr.trim();
    writeArtifact(job, "summary.md", buildSummary({ job, agentResult, verification, diff, resultText }));

    const finalJob = updateJob(job.id, {
      status: agentResult.code === 0 && verification.every((item) => item.code === 0) ? "ready" : "needs-attention",
      agentExitCode: agentResult.code,
      filesChanged: diff.nameOnly,
      diffStat: diff.stat,
      summary: summarizeResult(resultText, diff.nameOnly, verification),
      verification,
      finishedAt: new Date().toISOString()
    });
    onStatus?.({
      status: finalJob.status,
      message: finalJob.summary,
      job: finalJob
    });
    return finalJob;
  } catch (error) {
    writeArtifact(job, "error.log", `${error.stack ?? error.message}\n`);
    const failedJob = updateJob(job.id, {
      status: "failed",
      error: error.message,
      finishedAt: new Date().toISOString()
    });
    onStatus?.({
      status: "failed",
      message: error.message,
      job: failedJob
    });
    return failedJob;
  }
}

function loadScreenContext(screenContextDir) {
  if (!screenContextDir) {
    return null;
  }

  const metadataPath = path.join(screenContextDir, "metadata.json");
  if (!fs.existsSync(metadataPath)) {
    throw new Error(`Missing screen context metadata: ${metadataPath}`);
  }

  return JSON.parse(fs.readFileSync(metadataPath, "utf8"));
}

function copyScreenContextArtifacts(job, screenContextDir) {
  const targetDir = path.join(job.artifactsDir, "screen-context");
  fs.mkdirSync(targetDir, { recursive: true });

  for (const entry of fs.readdirSync(screenContextDir)) {
    const sourcePath = path.join(screenContextDir, entry);
    const targetPath = path.join(targetDir, entry);
    if (fs.statSync(sourcePath).isFile()) {
      fs.copyFileSync(sourcePath, targetPath);
    }
  }
}

async function runVerificationCommands(config, workspaceDir, shellCommandRunner) {
  const commands = [
    ["test", config.commands?.test],
    ["build", config.commands?.build],
    ["lint", config.commands?.lint]
  ].filter(([, command]) => command);

  const results = [];
  for (const [name, command] of commands) {
    const result = await shellCommandRunner({ command, cwd: workspaceDir });
    results.push({
      name,
      command,
      code: result.code,
      stdout: result.stdout.slice(-8000),
      stderr: result.stderr.slice(-8000),
      startedAt: result.startedAt,
      finishedAt: result.finishedAt
    });
  }
  return results;
}

function writeArtifact(job, fileName, content) {
  fs.mkdirSync(job.artifactsDir, { recursive: true });
  fs.writeFileSync(path.join(job.artifactsDir, fileName), `${content ?? ""}`);
}

function readIfExists(filePath) {
  return fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : "";
}

function summarizeResult(resultText, filesChanged, verification) {
  const verificationText = verification.length
    ? verification.map((item) => `${item.name}: ${item.code === 0 ? "passed" : "failed"}`).join(", ")
    : "no verification configured";
  const firstLine = resultText.split("\n").find((line) => line.trim())?.trim();
  return firstLine || `${filesChanged.length} files changed; ${verificationText}.`;
}

function buildSummary({ job, agentResult, verification, diff, resultText }) {
  return `# Workerflow Result

Job: ${job.id}
Agent: ${job.agent}
Status: ${agentResult.code === 0 ? "agent completed" : "agent exited with errors"}

## Agent Summary

${resultText || "No agent summary was produced."}

## Files Changed

${diff.nameOnly.length ? diff.nameOnly.map((file) => `- ${file}`).join("\n") : "No files changed."}

## Verification

${
  verification.length
    ? verification.map((item) => `- ${item.name}: ${item.code === 0 ? "passed" : "failed"} (${item.command})`).join("\n")
    : "No verification commands configured."
}

## Diff Stat

\`\`\`text
${diff.stat || "No diff."}
\`\`\`
`;
}
