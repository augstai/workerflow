# Clicky Reference Notes

Workerflow keeps a public fork of Clicky at <https://github.com/augstai/clicky> for research and attribution. The upstream project is <https://github.com/farzaa/clicky>.

Clicky is MIT licensed:

```text
Copyright (c) 2026 Farza
```

## Ground Rules

- Treat Clicky as an upstream reference, not a code source to silently absorb.
- Prefer clean-room implementations of ideas that fit Workerflow.
- Do not copy Clicky assets, branding, copy, screenshots, music, or product identity into Workerflow.
- If we copy a substantial code section, keep the MIT notice with that code and add a short attribution note in the relevant file or docs.
- Keep Workerflow's positioning distinct: developer workflow automation and coding-agent handoff, not a screen-teaching companion.
- Mention Clicky respectfully when a public change is directly inspired by it.

## Useful Patterns

- Native menu bar utility shape: no dock icon, status item entry point, floating panel, click-outside dismissal.
- Non-activating overlay windows: keep focus in the user's current app while showing status or guidance.
- Listen-only global hotkey monitor: modifier-only push-to-talk needs lower-level key transition handling than ordinary app shortcuts.
- Explicit permission center: microphone, accessibility, and screen permissions should be visible, testable, and recoverable.
- Voice state machine: idle, listening, processing, responding states should drive UI, audio meter, and user feedback.
- Pluggable transcription layer: provider abstraction with clear fallback behavior and provider-specific readiness checks.
- Audio diagnostics: live levels and a standalone test path make voice bugs much easier to isolate.
- Secret proxy for hosted mode: external API keys should live outside distributed apps; a small worker/proxy is a good future pattern for hosted/team features.
- Design-token discipline: shared color, spacing, radius, and motion tokens make the app feel coherent as it grows.
- Agent-readable architecture docs: keep a concise map of important files and behavioral contracts.

## Candidate Workerflow Adaptations

- Replace the current Electron global hotkey fallback with the native helper as the preferred hold-to-talk path on macOS.
- Add a first-run permission checklist with direct status, test buttons, and remediation copy.
- Add audio-level feedback during recording, not just a static listening state.
- Keep the desktop panel compact and command-focused, with settings hidden until needed.
- Add a tiny local/hosted proxy option later for teams that do not want provider keys on every machine.
- Maintain `AGENTS.md` as the repo-level source of truth for agent contributors.

See [clicky-deep-dive.md](clicky-deep-dive.md) for the deeper subsystem-level inspection.

## Non-Goals

- Do not clone Clicky's cursor companion, teacher persona, onboarding, or screen-pointing UX.
- Do not vendor the Clicky source tree into Workerflow.
- Do not depend on the fork at runtime.
- Do not present Workerflow as an official Clicky derivative or collaboration.
