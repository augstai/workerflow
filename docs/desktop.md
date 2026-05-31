# Desktop App

Workerflow's desktop app is a Mac-first tray app.

## Development

```bash
pnpm dev:desktop
```

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

The desktop app can run with the mock provider while UI and job flow are being developed. For OpenAI-compatible transcription:

```json
{
  "transcription": {
    "provider": "openai",
    "model": "gpt-4o-mini-transcribe",
    "apiKeyEnv": "OPENAI_API_KEY"
  }
}
```

Azure and ElevenLabs providers are planned behind the same provider interface.
