# Workerflow

Hold a key. Say the task. Your coding agent gets to work.

Workerflow is an open-source, Mac-first layer for launching coding-agent jobs from anywhere. The first product target is a tiny push-to-talk flow:

```text
hold hotkey -> speak -> release -> background agent job -> diff/result
```

The goal is not to build another chat app or full IDE. Workerflow should feel like a fast system utility for developers: capture intent, collect repo context, run an existing agent safely, and bring back a verified patch or summary.

## Status

This repository is at the project foundation stage. The current code provides:

- a runnable `workerflow` CLI
- project attach/status/doctor commands
- repo context capture
- safety defaults
- structured agent prompt generation
- Codex and Claude CLI adapter scaffolding
- an Electron tray app with a React/Vite hotkey overlay
- a native Swift/AppKit menu-bar shell scaffold
- a compact recording pill built with adapted ElevenLabs UI components
- configurable transcription providers
- OSS docs, issue templates, and CI

Native macOS packaging, the diff review surface, and broader adapter coverage are still active work.

## Quick Start

Requirements:

- Node.js 22+
- pnpm 10+
- git

```bash
pnpm install
pnpm workerflow attach --agent codex --test "pnpm test"
pnpm workerflow status
pnpm workerflow doctor
pnpm workerflow doctor --smoke-codex
pnpm workerflow prompt "Fix the failing auth test in a new worktree and run tests."
pnpm workerflow run --dry-run "Fix the failing auth test in a new worktree and run tests."
```

The `attach` command writes `.workerflow.json` in the current repository. That file tells Workerflow which agent to use, which commands verify the repo, and which paths should require extra care.

For voice transcription, copy `.env.example` to `.env` during local development or to `~/.workerflow/.env` for desktop-wide settings, then fill the provider keys. Workerflow loads those files without committing secrets.

## Product Shape

Workerflow has four layers:

1. Desktop shell: menu bar app, push-to-talk hotkey, recording pill, notifications.
2. Voice pipeline: transcription, cleanup, intent classification, action confirmation.
3. Context builder: git status, branch, diff summary, package metadata, repo config.
4. Agent runner: Codex CLI, Claude Code, Aider, or a custom shell command in an isolated worktree.

## Safety Defaults

Workerflow should be useful without being reckless:

- never auto-push
- never auto-merge
- never deploy without approval
- never spend money
- never edit `.env`
- use worktrees for code-changing jobs
- show a diff before applying results

See [docs/security-model.md](docs/security-model.md).

## Roadmap

The short version:

- v0.1: CLI, repo attach, context capture, prompt generation
- v0.2: agent adapter contracts and worktree runner
- v0.3: Electron tray app and hotkey overlay
- v0.4: transcription and task classification
- v0.5: diff viewer, notifications, demo-ready flow

See [docs/roadmap.md](docs/roadmap.md).

## Desktop App

Run the native Mac shell:

```bash
pnpm dev:mac
```

Build and test the native shell:

```bash
pnpm build:mac
pnpm test:mac
```

Debug the native shell:

```bash
pnpm workerflow debug
pnpm workerflow debug --bundle
```

Native logs live at `~/Library/Logs/Workerflow/workerflow-mac.log`.

Run the Electron prototype shell:

```bash
pnpm dev:desktop
```

Build the desktop renderer:

```bash
pnpm build:desktop
```

The tray app defaults to `Alt+Space`, which maps to Option+Space on macOS keyboards. The first implementation supports a reliable toggle hotkey through Electron. True hold-to-talk mode is wired for a native macOS helper and requires Accessibility permission:

```bash
apps/desktop/native/build-macos-hotkey-helper.sh
```

Then set `"hotkeyMode": "hold"` in `~/.workerflow/settings.json`.

See [docs/native-mac.md](docs/native-mac.md) for the Swift/AppKit shell.

## Open Source Sustainability

Workerflow is intended to be useful to maintainers and independent devtool builders. A healthy version of this project can support:

- community contributions
- GitHub Sponsors or paid support
- paid hosted/team features later
- consulting and integration work around agent workflows

The project should earn sustainability by being useful, documented, safe, and actively maintained.

## License

MIT
