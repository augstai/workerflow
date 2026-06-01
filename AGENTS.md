# Agent Notes

Workerflow is a Mac operator and developer utility. It starts from voice or quick commands, handles safe local Mac tasks directly when it can, and hands complex code-changing work to coding agents.

## Product Boundaries

- Build a Mac-first operator with coding-agent superpowers, not a generic chat app.
- Keep the coding-agent workflow first-class: repo context, worktrees, verification, diff review, and apply/reject.
- Add general Mac control only through explicit, policy-gated local tools such as Accessibility, ScreenCaptureKit, clipboard, Shortcuts, AppleScript, shell, and keyboard/mouse events.
- Prefer direct/local action for safe tasks, and hand off to Codex, Claude Code, or Aider when the task needs codebase reasoning or broad edits.
- Use existing agents such as Codex CLI, Claude Code, and Aider.
- Keep code-changing jobs isolated in git worktrees.
- Show diffs before applying changes.
- Ask for approval before destructive actions, external submissions, spending money, sending messages, deleting files, or running risky shell commands.

## Repository Conventions

- Use plain JavaScript until the TypeScript/Electron workspace is introduced.
- Keep core workflow logic in `packages/core`.
- Keep command-line entrypoints in `apps/cli`.
- Avoid network dependencies in foundational tests.
- Prefer small, auditable modules.
