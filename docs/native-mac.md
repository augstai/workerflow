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

## Attribution

The native shell adapts Mac app architecture patterns from Clicky by Farza, which is MIT licensed. Attribution lives in `apps/mac/NOTICE.md`.
