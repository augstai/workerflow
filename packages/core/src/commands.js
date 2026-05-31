import { spawn, spawnSync } from "node:child_process";

export function commandExists(command) {
  const result = spawnSync("command", ["-v", command], {
    encoding: "utf8",
    shell: true,
    stdio: ["ignore", "pipe", "ignore"]
  });

  return {
    ok: result.status === 0,
    path: result.stdout.trim()
  };
}

export function runCommand({ command, args = [], cwd, input, env, onData, timeoutMs }) {
  return new Promise((resolve) => {
    const startedAt = new Date().toISOString();
    let timedOut = false;
    const child = spawn(command, args, {
      cwd,
      env: {
        ...process.env,
        ...(env ?? {})
      },
      shell: false,
      stdio: ["pipe", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      const value = chunk.toString();
      stdout += value;
      onData?.({ stream: "stdout", value });
    });

    child.stderr.on("data", (chunk) => {
      const value = chunk.toString();
      stderr += value;
      onData?.({ stream: "stderr", value });
    });

    child.on("error", (error) => {
      stderr += `${error.message}\n`;
    });

    const timeout = timeoutMs
      ? setTimeout(() => {
          timedOut = true;
          stderr += `Workerflow timed out after ${timeoutMs}ms.\n`;
          child.kill("SIGTERM");
        }, timeoutMs)
      : null;

    child.on("close", (code, signal) => {
      if (timeout) {
        clearTimeout(timeout);
      }
      resolve({
        command,
        args,
        cwd,
        code: code ?? 1,
        signal,
        stdout,
        stderr,
        timedOut,
        startedAt,
        finishedAt: new Date().toISOString()
      });
    });

    if (input) {
      child.stdin.write(input);
    }
    child.stdin.end();
  });
}

export function runShellCommand({ command, cwd }) {
  return new Promise((resolve) => {
    const startedAt = new Date().toISOString();
    const child = spawn(command, {
      cwd,
      shell: true,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      stderr += `${error.message}\n`;
    });

    child.on("close", (code, signal) => {
      resolve({
        command,
        code: code ?? 1,
        signal,
        stdout,
        stderr,
        startedAt,
        finishedAt: new Date().toISOString()
      });
    });
  });
}
