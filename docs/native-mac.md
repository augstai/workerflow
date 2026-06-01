# Native Mac Shell

Workerflow's primary desktop path is the Swift/AppKit shell in `apps/mac`.

```bash
pnpm dev:mac
pnpm dev:mac:gallery
pnpm build:mac
pnpm test:mac
```

The app is a menu-bar utility with no Dock window. It uses:

- `NSStatusItem` for the menu-bar entry
- non-activating `NSPanel` surfaces for the control panel and voice pill
- native microphone and Accessibility permission checks
- ScreenCaptureKit screen-context capture
- a listen-only global event tap for hold-to-talk
- `AVAudioEngine` for temporary `.wav` voice capture and live audio levels
- native Swift voice-agent visual components for the pill, voice action button, and bar visualizer states
- the existing `workerflow` CLI for transcription and agent runs

The default hotkey is Option+Space. The panel can switch to Control+Option, Control+Option+Space, or Shift+Control+Space.

`pnpm dev:mac:gallery` opens a native Swift/AppKit UI gallery with mock state. It includes the actual pill, panel, voice action button, and bar visualizer states. It does not start permission polling, microphone capture, screen capture, transcription, or agent jobs, so UI changes can be reviewed quickly in the actual Swift surfaces.

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

- Screen Recording: screen context for coding-agent jobs
- Screen Content: a lightweight ScreenCaptureKit probe confirms capture works after permission is granted

The app includes `Info.plist` and entitlements for packaging, but the current development command runs through SwiftPM. A signed `.app` bundle is the next packaging step.

Manual TCC smoke checklist for signed builds:

1. Launch the app from the signed `.app`, not `swift run`.
2. Grant Microphone and confirm the waveform reacts to live audio.
3. Grant Accessibility and confirm the global hold-to-talk shortcut works from another app.
4. Grant Screen Recording, quit, relaunch, then run Screen Content verification.
5. On a multi-monitor setup, start a job and confirm screen-context artifacts include all displays with the cursor display labeled.

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
- hosted speech/TTS/proxy services
- onboarding media, music, copy, assets, analytics, or hosted service endpoints
