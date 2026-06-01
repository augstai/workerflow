# Architecture

Workerflow has four layers.

## Desktop Shell

The desktop shell is a Mac-first tray app with:

- global push-to-talk hotkey
- small always-on-top recording overlay
- local notifications
- job list and result panel
- approval prompts for risky actions

The preferred Mac shell lives in `apps/mac`. It uses SwiftUI/AppKit for the menu-bar app, non-activating panels, native permission prompts, microphone capture, and listen-only push-to-talk monitoring.

The Node core remains the source of truth for repo context, transcription providers, job creation, worktrees, and agent adapters. The native shell bridges into it through the `workerflow` CLI.

The Electron shell remains as a prototype fallback while the native shell reaches feature parity.

## Voice Pipeline

The voice path should convert speech into a normalized task:

```text
raw audio -> transcript -> cleaned command -> intent -> job request
```

The pipeline should support two modes:

- dictation: paste cleaned text into the active app
- action: run a coding-agent job

Action mode should show a compact confirmation when the task is risky.

## Context Builder

The context builder turns a vague command like "fix this" into a useful job:

- current repo
- git branch
- git status
- diff summary
- package manager
- configured test/build/lint commands
- project instructions such as `AGENTS.md` or `CLAUDE.md`
- optional terminal/screen context later

The current implementation starts this layer in `packages/core/src/context.js`.

## Agent Runner

Workerflow should wrap existing agents instead of replacing them:

- Codex CLI
- Claude Code
- Aider
- custom shell command

The runner should create a new worktree for code-changing jobs, invoke the selected adapter, capture logs, run verification commands, and return a patch summary.
