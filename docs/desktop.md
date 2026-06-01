# Desktop App

Workerflow's desktop app is a Mac-first tray app with a compact React/Vite overlay.

## Development

```bash
pnpm dev:desktop
```

Build the packaged renderer assets:

```bash
pnpm build:desktop
```

Check local agent wiring:

```bash
pnpm workerflow doctor
pnpm workerflow doctor --smoke-codex
pnpm workerflow doctor --smoke-claude
```

The smoke checks intentionally run only when requested because they may use provider credits.

The app reads `~/.workerflow/settings.json`. Defaults:

```json
{
  "activeRepo": "/path/to/repo",
  "agent": "codex",
  "hotkey": "Alt+Space",
  "hotkeyMode": "toggle",
  "transcription": {
    "provider": "mock",
    "model": "gpt-4o-mini-transcribe"
  }
}
```

`Alt+Space` maps to Option+Space on macOS.

## Renderer

The desktop renderer lives in `apps/desktop/renderer` and uses React, Vite, Tailwind, and adapted ElevenLabs UI components for the voice button and live waveform.

The adapted component files are kept under `apps/desktop/renderer/src/components/elevenlabs-ui` with a local notice file. Keep attribution intact when editing or adding copied components.

## Hold-To-Talk

Electron's built-in global shortcut API detects hotkey activation but does not expose global key release. True hold-to-talk mode uses the native macOS helper in `apps/desktop/native`.

Build it with:

```bash
apps/desktop/native/build-macos-hotkey-helper.sh
```

Then set:

```json
{
  "hotkeyMode": "hold"
}
```

macOS must grant Accessibility permission to the terminal or packaged app that starts Workerflow.

## Transcription Providers

The desktop app can run with the mock provider while UI and job flow are being developed. The provider can be changed in the app settings panel or by editing `~/.workerflow/settings.json`.

Secrets can live in a local env file. Workerflow loads `.env` from the directory where it is started, then `~/.workerflow/.env`; already-exported shell variables win over file values. For Azure OpenAI, copy `.env.example` and fill:

```dotenv
WORKERFLOW_TRANSCRIPTION_PROVIDER=azure-openai
AZURE_OPENAI_ENDPOINT=https://YOUR_RESOURCE.openai.azure.com
AZURE_OPENAI_TRANSCRIPTION_DEPLOYMENT=YOUR_TRANSCRIPTION_DEPLOYMENT_NAME
AZURE_OPENAI_API_VERSION=2025-03-01-preview
AZURE_OPENAI_API_KEY=YOUR_AZURE_OPENAI_KEY
```

Use the desktop voice button to verify microphone permission, recording, provider config, and transcription before running an agent job.

OpenAI:

```json
{
  "transcription": {
    "provider": "openai",
    "model": "gpt-4o-mini-transcribe",
    "apiKeyEnv": "OPENAI_API_KEY"
  }
}
```

Azure OpenAI:

```json
{
  "transcription": {
    "provider": "azure-openai",
    "azureEndpoint": "https://YOUR_RESOURCE.openai.azure.com",
    "azureDeployment": "YOUR_TRANSCRIPTION_DEPLOYMENT",
    "azureApiVersion": "2025-03-01-preview",
    "azureApiKeyEnv": "AZURE_OPENAI_API_KEY"
  }
}
```

ElevenLabs:

```json
{
  "transcription": {
    "provider": "elevenlabs",
    "elevenLabsModel": "scribe_v2",
    "elevenLabsApiKeyEnv": "ELEVENLABS_API_KEY"
  }
}
```
