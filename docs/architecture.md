# Architecture

Workerflow has six layers. The original coding-agent launcher remains the strongest workflow, but the product now also supports an optional Mac operator mode for safe desktop tasks.

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

The pipeline should support three modes:

- dictation: paste cleaned text into the active app
- direct Mac action: run a safe local tool without agent handoff
- coding action: run a coding-agent job

Action mode should show a compact confirmation when the task is risky.

## Intent Router

The router decides whether Workerflow should handle the task directly, guide a desktop workflow, or hand it to Codex/Claude/Aider.

```text
transcript -> cleanup -> router -> direct action | guided Mac operator | coding-agent handoff | clarification
```

Default routing:

- simple local UI/app tasks use direct Mac action
- broad desktop tasks use guided Mac operator mode
- codebase edits use coding-agent handoff
- risky or ambiguous tasks ask for approval or clarification

## Mac Operator Tool Layer

The operator layer exposes local Mac capabilities behind mockable protocols and policy checks:

- Accessibility tree reads and element actions
- ScreenCaptureKit screenshots and display metadata
- clipboard and selected-text workflows
- AppleScript, Shortcuts, and app-specific automation
- safe shell reads
- keyboard/mouse event actions only as fallback

The model should not own raw desktop control. Workerflow should route every tool call through local policy, logging, and approval gates.

## Context Builder

The context builder turns a vague command like "fix this" into a useful job:

- current repo
- git branch
- git status
- diff summary
- package manager
- configured test/build/lint commands
- project instructions such as `AGENTS.md` or `CLAUDE.md`
- optional terminal/screen context
- optional active-app, selected-text, clipboard, and Accessibility context for operator mode

The current implementation starts this layer in `packages/core/src/context.js`.

## Agent Runner

Workerflow should wrap existing agents instead of replacing them:

- Codex CLI
- Claude Code
- Aider
- custom shell command

The runner should create a new worktree for code-changing jobs, invoke the selected adapter, capture logs, run verification commands, and return a patch summary.

## Commercial Layer

The desktop app can support free trial, monthly, annual, and lifetime licensing later. Billing and hosted model access should sit outside foundational tests, and networked services should remain behind explicit configuration.
