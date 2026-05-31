import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";

const STORE_DIR = path.join(os.homedir(), ".workerflow");
const STORE_FILE = path.join(STORE_DIR, "jobs.json");
const JOBS_DIR = path.join(STORE_DIR, "jobs");

export function workerflowHome() {
  return STORE_DIR;
}

export function jobArtifactsDir(jobId) {
  return path.join(JOBS_DIR, jobId);
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

function readStore() {
  if (!fs.existsSync(STORE_FILE)) {
    return { jobs: [] };
  }

  return JSON.parse(fs.readFileSync(STORE_FILE, "utf8"));
}

function writeStore(store) {
  fs.mkdirSync(STORE_DIR, { recursive: true });
  fs.writeFileSync(STORE_FILE, `${JSON.stringify(store, null, 2)}\n`);
}
