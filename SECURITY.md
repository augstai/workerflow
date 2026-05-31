# Security Policy

Workerflow runs local commands and may inspect repository context. That makes safety a core feature, not an afterthought.

## Reporting Issues

Please open a private security advisory on GitHub if the issue could expose secrets, run unwanted commands, bypass approvals, or leak repository data.

If private advisories are unavailable, email the maintainer listed on the GitHub repository.

## Scope

Security-sensitive areas include:

- command execution
- worktree creation and patch application
- path allow/deny rules
- transcription and model providers
- local logs and job storage
- agent adapter permissions
- any future GitHub or external-service integrations

## Defaults

Workerflow should never auto-push, auto-deploy, spend money, edit `.env`, or publish content externally without explicit approval.
