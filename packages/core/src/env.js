import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const ENV_KEY_PATTERN = /^[A-Za-z_][A-Za-z0-9_]*$/;

export function workerflowEnvPath() {
  return path.join(os.homedir(), ".workerflow", ".env");
}

export function loadEnvironment({ cwd = process.cwd(), override = false, includeHome = true } = {}) {
  const files = environmentFiles(cwd, { includeHome });
  const loaded = [];

  for (const filePath of files) {
    if (!fs.existsSync(filePath)) continue;

    const entries = parseEnvFile(fs.readFileSync(filePath, "utf8"));
    let applied = 0;

    for (const [key, value] of Object.entries(entries)) {
      if (override || process.env[key] === undefined) {
        process.env[key] = value;
        applied += 1;
      }
    }

    loaded.push({ path: filePath, keys: Object.keys(entries), applied });
  }

  return loaded;
}

export function environmentFiles(cwd = process.cwd(), { includeHome = true } = {}) {
  return [
    process.env.WORKERFLOW_ENV_FILE,
    path.join(cwd, ".env"),
    includeHome ? workerflowEnvPath() : ""
  ].filter(uniqueTruthy);
}

export function parseEnvFile(raw) {
  const entries = {};

  for (const originalLine of raw.split(/\r?\n/)) {
    const line = originalLine.trim();
    if (!line || line.startsWith("#")) continue;

    const withoutExport = line.startsWith("export ") ? line.slice("export ".length).trim() : line;
    const equalsIndex = withoutExport.indexOf("=");
    if (equalsIndex === -1) continue;

    const key = withoutExport.slice(0, equalsIndex).trim();
    if (!ENV_KEY_PATTERN.test(key)) continue;

    entries[key] = parseEnvValue(withoutExport.slice(equalsIndex + 1).trim());
  }

  return entries;
}

function parseEnvValue(value) {
  if (!value) return "";

  const quote = value[0];
  if ((quote === "\"" || quote === "'") && value.at(-1) === quote) {
    const unquoted = value.slice(1, -1);
    if (quote === "\"") {
      return unquoted.replace(/\\n/g, "\n").replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
    }
    return unquoted;
  }

  const commentIndex = value.search(/\s#/);
  return (commentIndex === -1 ? value : value.slice(0, commentIndex)).trim();
}

function uniqueTruthy(value, index, list) {
  return Boolean(value) && list.indexOf(value) === index;
}
