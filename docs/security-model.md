# Security Model

Workerflow is designed around local developer trust boundaries.

## Default Assumptions

- Source code is sensitive.
- Terminal output may contain secrets.
- Voice transcripts may contain private context.
- Coding agents can make broad changes if not constrained.
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
