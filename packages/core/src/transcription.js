import fs from "node:fs";
import path from "node:path";
import { cleanSpokenCommand } from "./task.js";

export async function transcribeAudioFile({ filePath, config, prompt }) {
  const transcriptionConfig = resolveTranscriptionConfig(config);
  const provider = transcriptionConfig.provider ?? "mock";
  const resolvedConfig = {
    ...config,
    transcription: transcriptionConfig
  };

  if (provider === "mock") {
    return {
      provider,
      transcript: path.basename(filePath).replace(/\.[^.]+$/, "").replace(/[-_]/g, " "),
      cleaned: cleanSpokenCommand(path.basename(filePath).replace(/\.[^.]+$/, "").replace(/[-_]/g, " "))
    };
  }

  if (provider === "openai") {
    return transcribeWithOpenAI({ filePath, config: resolvedConfig, prompt });
  }

  if (provider === "openai-compatible") {
    return transcribeWithOpenAICompatible({ filePath, config: resolvedConfig, prompt });
  }

  if (provider === "azure-openai") {
    return transcribeWithAzureOpenAI({ filePath, config: resolvedConfig, prompt });
  }

  if (provider === "elevenlabs") {
    return transcribeWithElevenLabs({ filePath, config: resolvedConfig, prompt });
  }

  throw new Error(`Unsupported transcription provider "${provider}"`);
}

function resolveTranscriptionConfig(config) {
  const transcriptionConfig = config.transcription ?? {};
  return {
    ...transcriptionConfig,
    provider: envValue("WORKERFLOW_TRANSCRIPTION_PROVIDER") ?? transcriptionConfig.provider,
    model: envValue("OPENAI_TRANSCRIPTION_MODEL") ?? transcriptionConfig.model,
    apiKeyEnv: envValue("OPENAI_API_KEY_ENV") ?? transcriptionConfig.apiKeyEnv,
    baseUrl: envValue("OPENAI_BASE_URL") ?? transcriptionConfig.baseUrl,
    azureEndpoint: envValue("AZURE_OPENAI_ENDPOINT") ?? transcriptionConfig.azureEndpoint,
    azureDeployment:
      envValue("AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT") ??
      envValue("AZURE_OPENAI_DEPLOYMENT") ??
      transcriptionConfig.azureDeployment,
    azureApiVersion: envValue("AZURE_OPENAI_API_VERSION") ?? transcriptionConfig.azureApiVersion,
    azureApiKeyEnv: envValue("AZURE_OPENAI_API_KEY_ENV") ?? transcriptionConfig.azureApiKeyEnv,
    elevenLabsApiKeyEnv: envValue("ELEVENLABS_API_KEY_ENV") ?? transcriptionConfig.elevenLabsApiKeyEnv,
    elevenLabsModel: envValue("ELEVENLABS_TRANSCRIPTION_MODEL") ?? transcriptionConfig.elevenLabsModel
  };
}

function envValue(key) {
  const value = process.env[key]?.trim();
  return value ? value : undefined;
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

  const payload = await readResponsePayload(response);
  if (!response.ok) {
    throw new Error(payload.error?.message ?? `Transcription failed with status ${response.status}`);
  }

  const transcript = normalizeTranscript({
    transcript: typeof payload === "string" ? payload : payload.text ?? "",
    prompt
  });
  return {
    provider: transcriptionConfig.provider,
    transcript,
    cleaned: cleanSpokenCommand(transcript),
    raw: payload
  };
}

async function transcribeWithAzureOpenAI({ filePath, config, prompt }) {
  const transcriptionConfig = config.transcription ?? {};
  const endpoint = transcriptionConfig.azureEndpoint?.replace(/\/$/, "");
  const deployment = transcriptionConfig.azureDeployment;
  const apiVersion = transcriptionConfig.azureApiVersion ?? "2025-03-01-preview";
  const apiKeyEnv = transcriptionConfig.azureApiKeyEnv ?? "AZURE_OPENAI_API_KEY";
  const apiKey = process.env[apiKeyEnv];

  if (!endpoint) {
    throw new Error("Missing transcription.azureEndpoint");
  }

  if (!deployment) {
    throw new Error("Missing transcription.azureDeployment");
  }

  if (!apiKey) {
    throw new Error(`Missing ${apiKeyEnv} for Azure OpenAI transcription`);
  }

  const audio = new Blob([fs.readFileSync(filePath)], {
    type: guessMimeType(filePath)
  });
  const form = new FormData();
  form.append("file", audio, path.basename(filePath));
  if (prompt) {
    form.append("prompt", prompt);
  }

  const response = await fetch(
    `${endpoint}/openai/deployments/${deployment}/audio/transcriptions?api-version=${apiVersion}`,
    {
      method: "POST",
      headers: {
        "api-key": apiKey
      },
      body: form
    }
  );

  const payload = await readResponsePayload(response);
  if (!response.ok) {
    throw new Error(payload.error?.message ?? `Azure OpenAI transcription failed with status ${response.status}`);
  }

  const transcript = normalizeTranscript({
    transcript: typeof payload === "string" ? payload : payload.text ?? "",
    prompt
  });
  return {
    provider: transcriptionConfig.provider,
    transcript,
    cleaned: cleanSpokenCommand(transcript),
    raw: payload
  };
}

async function transcribeWithElevenLabs({ filePath, config }) {
  const transcriptionConfig = config.transcription ?? {};
  const apiKeyEnv = transcriptionConfig.elevenLabsApiKeyEnv ?? "ELEVENLABS_API_KEY";
  const apiKey = process.env[apiKeyEnv];

  if (!apiKey) {
    throw new Error(`Missing ${apiKeyEnv} for ElevenLabs transcription`);
  }

  const audio = new Blob([fs.readFileSync(filePath)], {
    type: guessMimeType(filePath)
  });
  const form = new FormData();
  form.append("model_id", transcriptionConfig.elevenLabsModel ?? transcriptionConfig.model ?? "scribe_v2");
  form.append("file", audio, path.basename(filePath));

  const response = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
    method: "POST",
    headers: {
      "xi-api-key": apiKey
    },
    body: form
  });

  const payload = await readResponsePayload(response);
  if (!response.ok) {
    throw new Error(payload.detail?.message ?? payload.error?.message ?? `ElevenLabs transcription failed with status ${response.status}`);
  }

  const transcript = normalizeTranscript({
    transcript: typeof payload === "string" ? payload : payload.text ?? ""
  });
  return {
    provider: transcriptionConfig.provider,
    transcript,
    cleaned: cleanSpokenCommand(transcript),
    raw: payload
  };
}

async function readResponsePayload(response) {
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    return response.json();
  }
  return response.text();
}

function normalizeTranscript({ transcript, prompt }) {
  const normalized = String(transcript ?? "").trim();
  if (!normalized) {
    throw new Error("No speech detected. Hold the hotkey while speaking, then release.");
  }

  if (prompt && normalized.toLowerCase() === prompt.trim().toLowerCase()) {
    throw new Error("No speech detected. Hold the hotkey while speaking, then release.");
  }

  return normalized;
}

function guessMimeType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".webm") return "audio/webm";
  if (ext === ".wav") return "audio/wav";
  if (ext === ".mp3") return "audio/mpeg";
  if (ext === ".m4a") return "audio/mp4";
  return "application/octet-stream";
}
