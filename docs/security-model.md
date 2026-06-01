# Security Model

Workerflow is designed around local developer trust boundaries.

## Default Assumptions

- Source code is sensitive.
- Terminal output may contain secrets.
- Voice transcripts may contain private context.
- Screen captures, Accessibility trees, clipboard contents, and selected text may contain private context.
- Coding agents can make broad changes if not constrained.
- Desktop-control tools can click, type, submit forms, and delete files if not constrained.
- External actions like pushing, deploying, commenting, or spending money require explicit approval.

## Hard Defaults

Workerflow should not automatically:

- push commits or branches
- merge pull requests
- deploy
- edit `.env` or credential files
- delete large directories
- modify payment, auth, or migration code without elevated review
- send comments, emails, or issues externally
- spend money
- submit forms, make reservations, send messages, or book anything
- grant macOS permissions or change system privacy settings
- run desktop-control actions without a visible in-app state

## Worktree Isolation

Code-changing jobs should run in a separate git worktree by default.

This gives users:

- a clean original checkout
- an isolated branch for the agent
- easy diff review
- easy discard path

## Result Review

Workerflow should return:

- files changed
- commands run
- test/build/lint status
- concise summary
- risks and followups
- patch or diff

Applying a patch back to the main checkout should be an explicit user action.

## Mac Operator Mode

Mac operator mode is allowed, but it must be policy-gated.

Read-only context tools are safest:

- active app/window
- Accessibility tree
- selected text
- clipboard
- screen capture
- disk usage summaries

Action tools require stronger controls:

- `open_app`, `focus_window`, `set_clipboard`, and safe hotkeys can run directly when low risk.
- `click_element`, `type_text`, `replace_selection`, shell commands, AppleScript, Shortcuts, and coordinate clicks must pass the local policy layer.
- destructive, external, financial, account, permission, or submission actions must ask first.

Screen context remains optional. Voice capture must work without Screen Recording or Screen Content access.

## User-Visible Control

When Workerflow is operating the Mac, the UI should show:

- current state
- current app/tool being inspected or acted on
- whether screen context is in use
- pending approval when needed
- stop/cancel affordance

The user should be able to interrupt the operator loop at any time.
