# Native Mac Shell

Workerflow's primary desktop path is the Swift/AppKit shell in `apps/mac`.

```bash
pnpm dev:mac
pnpm build:mac
pnpm test:mac
```

The app is a menu-bar utility with no Dock window. It uses:

- `NSStatusItem` for the menu-bar entry
- non-activating `NSPanel` surfaces for the control panel and voice pill
- native microphone and Accessibility permission checks
- a listen-only global event tap for hold-to-talk
- `AVAudioRecorder` for temporary `.m4a` voice capture
- the existing `workerflow` CLI for transcription and agent runs

The default hotkey is Option+Space. The panel can switch to Control+Option, Control+Option+Space, or Shift+Control+Space.

## Runtime Flow

```text
hold hotkey -> record local audio -> release -> workerflow transcribe -> review task -> workerflow run
```

The Swift app does not store provider keys. It inherits the same environment loading path as the CLI: local `.env`, `~/.workerflow/.env`, or exported shell variables. Keep secrets out of tracked files.

## Permissions

Required:

- Microphone: voice capture
- Accessibility: global push-to-talk event tap

Optional:

- Screen Recording: reserved for future screen-context capture

The app includes `Info.plist` and entitlements for packaging, but the current development command runs through SwiftPM. A signed `.app` bundle is the next packaging step.

## Debugging

The native shell writes persistent logs even when the terminal is not useful:

```text
~/Library/Logs/Workerflow/workerflow-mac.log
```

The menu-bar panel has a small support menu:

- `Open Log File`: reveals the native Mac log in Finder.
- `Create Support Report`: creates a redacted diagnostics bundle through `workerflow debug --bundle`.

CLI diagnostics:

```bash
pnpm workerflow debug
pnpm workerflow debug --bundle
```

Bundles are written under:

```text
~/.workerflow/diagnostics/
```

They include safe runtime metadata, recent job artifact indexes, env key presence, and the recent native app log. API key values, bearer tokens, and secret-looking fields are redacted before writing.

Job-specific artifacts still live under:

```text
~/.workerflow/jobs/<job-id>/
```

## Attribution

The native shell adapts Mac app architecture patterns from Clicky by Farza, which is MIT licensed. Attribution lives in `apps/mac/NOTICE.md`.

What is currently adapted:

- menu-bar-only native host
- compact non-activating panels
- native permission recovery shape
- listen-only push-to-talk event tap
- central observable app state
- dark compact visual language

What is not copied yet:

- cursor companion / mouse-following teaching overlay
- screen-pointing coordinate system
- screen capture pipeline
- onboarding media, music, copy, assets, analytics, or hosted service endpoints
