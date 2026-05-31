import fs from "node:fs";
import path from "node:path";
import { cleanSpokenCommand } from "./task.js";

export async function transcribeAudioFile({ filePath, config, prompt }) {
  const provider = config.transcription?.provider ?? "mock";

  if (provider === "mock") {
    return {
      provider,
      transcript: path.basename(filePath).replace(/\.[^.]+$/, "").replace(/[-_]/g, " "),
      cleaned: cleanSpokenCommand(path.basename(filePath).replace(/\.[^.]+$/, "").replace(/[-_]/g, " "))
    };
  }

  if (provider === "openai") {
    return transcribeWithOpenAI({ filePath, config, prompt });
  }

  if (provider === "openai-compatible") {
    return transcribeWithOpenAICompatible({ filePath, config, prompt });
  }

  throw new Error(`Unsupported transcription provider "${provider}"`);
}

async function transcribeWithOpenAI({ filePath, config, prompt }) {
  return transcribeWithOpenAICompatible({
    filePath,
    config: {
      ...config,
      transcription: {
        ...config.transcription,
        baseUrl: config.transcription?.baseUrl ?? "https://api.openai.com/v1",
        apiKeyEnv: config.transcription?.apiKeyEnv ?? "OPENAI_API_KEY"
      }
    },
    prompt
  });
}

async function transcribeWithOpenAICompatible({ filePath, config, prompt }) {
  const transcriptionConfig = config.transcription ?? {};
  const baseUrl = transcriptionConfig.baseUrl;
  const apiKeyEnv = transcriptionConfig.apiKeyEnv ?? "OPENAI_API_KEY";
  const apiKey = process.env[apiKeyEnv];

  if (!baseUrl) {
    throw new Error("Missing transcription.baseUrl for openai-compatible provider");
  }

  if (!apiKey) {
    throw new Error(`Missing ${apiKeyEnv} for transcription provider`);
  }

  const audio = new Blob([fs.readFileSync(filePath)], {
    type: guessMimeType(filePath)
  });
  const form = new FormData();
  form.append("file", audio, path.basename(filePath));
  form.append("model", transcriptionConfig.model ?? "gpt-4o-mini-transcribe");
  if (prompt) {
    form.append("prompt", prompt);
  }

  const response = await fetch(`${baseUrl.replace(/\/$/, "")}/audio/transcriptions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`
    },
    body: form
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error?.message ?? `Transcription failed with status ${response.status}`);
  }

  const transcript = payload.text ?? "";
  return {
    provider: transcriptionConfig.provider,
    transcript,
    cleaned: cleanSpokenCommand(transcript),
    raw: payload
  };
}

function guessMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".webm") return "audio/webm";
  if (ext === ".wav") return "audio/wav";
  if (ext === ".mp3") return "audio/mpeg";
  if (ext === ".m4a") return "audio/mp4";
  return "application/octet-stream";
}
