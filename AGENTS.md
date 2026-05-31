# Agent Notes

Workerflow is a developer utility for launching coding-agent jobs from voice or quick commands.

## Product Boundaries

- Build a focused coding-agent launcher, not a general assistant.
- Use existing agents such as Codex CLI, Claude Code, and Aider.
- Keep code-changing jobs isolated in git worktrees.
- Show diffs before applying changes.

## Repository Conventions

- Use plain JavaScript until the TypeScript/Electron workspace is introduced.
- Keep core workflow logic in `packages/core`.
- Keep command-line entrypoints in `apps/cli`.
- Avoid network dependencies in foundational tests.
- Prefer small, auditable modules.
