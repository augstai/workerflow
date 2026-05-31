import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";

const STORE_DIR = path.join(os.homedir(), ".workerflow");
const STORE_FILE = path.join(STORE_DIR, "jobs.json");

export function listJobs() {
  return readStore().jobs;
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
    createdAt: new Date().toISOString()
  };

  store.jobs.unshift(record);
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
