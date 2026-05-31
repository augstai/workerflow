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
- project attach/status commands
- repo context capture
- safety defaults
- structured agent prompt generation
- OSS docs, issue templates, and CI

The desktop app, voice pipeline, and agent adapters are next.

## Quick Start

Requirements:

- Node.js 22+
- pnpm 10+
- git

```bash
pnpm install
pnpm workerflow attach --agent codex --test "pnpm test"
pnpm workerflow status
pnpm workerflow prompt "Fix the failing auth test in a new worktree and run tests."
```

The `attach` command writes `.workerflow.json` in the current repository. That file tells Workerflow which agent to use, which commands verify the repo, and which paths should require extra care.

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

## Open Source Sustainability

Workerflow is intended to be useful to maintainers and independent devtool builders. A healthy version of this project can support:

- community contributions
- GitHub Sponsors or paid support
- paid hosted/team features later
- consulting and integration work around agent workflows

The project should earn sustainability by being useful, documented, safe, and actively maintained.

## License

MIT
