import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { git } from "./git.js";

export function workerflowHome() {
  return process.env.WORKERFLOW_HOME || path.join(os.homedir(), ".workerflow");
}

export function jobArtifactsDir(jobId) {
  return path.join(workerflowHome(), "jobs", jobId);
}

export function listJobs() {
  return readStore().jobs;
}

export function getJob(id) {
  return readStore().jobs.find((job) => job.id === id) ?? null;
}

export function createJob({ task, repoRoot, branch, agent, prompt }) {
  const store = readStore();
  const record = {
    id: `job_${new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14)}_${crypto
      .randomBytes(3)
      .toString("hex")}`,
    status: "queued",
    task,
    repoRoot,
    branch,
    agent,
    prompt,
    artifactsDir: "",
    createdAt: new Date().toISOString()
  };
  record.artifactsDir = jobArtifactsDir(record.id);

  store.jobs.unshift(record);
  writeStore(store);
  fs.mkdirSync(record.artifactsDir, { recursive: true });
  return record;
}

export function updateJob(id, patch) {
  const store = readStore();
  const index = store.jobs.findIndex((job) => job.id === id);
  if (index === -1) {
    throw new Error(`Unknown Workerflow job: ${id}`);
  }

  const record = {
    ...store.jobs[index],
    ...patch,
    updatedAt: new Date().toISOString()
  };
  store.jobs[index] = record;
  writeStore(store);
  return record;
}

export function applyJobPatch(id) {
  const job = getJob(id);
  if (!job) {
    throw new Error(`Unknown Workerflow job: ${id}`);
  }

  if (!["ready", "needs-attention"].includes(job.status)) {
    throw new Error(`Job ${id} is not ready to apply; current status is ${job.status}.`);
  }

  const patchPath = path.join(job.artifactsDir, "diff.patch");
  if (!fs.existsSync(patchPath) || fs.readFileSync(patchPath, "utf8").trim() === "") {
    return updateJob(id, {
      status: "applied",
      summary: "No diff to apply.",
      appliedAt: new Date().toISOString()
    });
  }

  const check = git(["apply", "--binary", "--check", patchPath], job.repoRoot);
  if (!check.ok) {
    const details = check.stderr || check.stdout;
    throw new Error(details ? `Patch does not apply cleanly.\n${details}` : "Patch does not apply cleanly.");
  }

  const apply = git(["apply", "--binary", patchPath], job.repoRoot);
  if (!apply.ok) {
    throw new Error(apply.stderr || apply.stdout || "Failed to apply patch.");
  }

  return updateJob(id, {
    status: "applied",
    summary: "Patch applied to the main checkout.",
    appliedAt: new Date().toISOString()
  });
}

export function rejectJob(id) {
  const job = getJob(id);
  if (!job) {
    throw new Error(`Unknown Workerflow job: ${id}`);
  }

  return updateJob(id, {
    status: "rejected",
    summary: "Job rejected; main checkout was not changed.",
    rejectedAt: new Date().toISOString()
  });
}

function readStore() {
  const storeFile = storeFilePath();
  if (!fs.existsSync(storeFile)) {
    return { jobs: [] };
  }

  return JSON.parse(fs.readFileSync(storeFile, "utf8"));
}

function writeStore(store) {
  const storeFile = storeFilePath();
  fs.mkdirSync(path.dirname(storeFile), { recursive: true });
  fs.writeFileSync(storeFile, `${JSON.stringify(store, null, 2)}\n`);
}

function storeFilePath() {
  return path.join(workerflowHome(), "jobs.json");
}
