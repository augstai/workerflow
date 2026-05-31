# Contributing

Thanks for helping build Workerflow.

## Local Setup

```bash
pnpm install
pnpm check
```

Run the CLI locally:

```bash
pnpm workerflow status
```

## Development Principles

- Keep the product small and direct.
- Prefer existing coding agents over building a new one.
- Treat user repositories as sensitive local data.
- Require approval before destructive, external, or expensive actions.
- Make risky behavior visible in docs and UI.

## Pull Requests

Good pull requests include:

- a short problem statement
- focused changes
- tests for core behavior
- screenshots or terminal output for user-facing flows
- notes about safety implications

## Project Areas

- CLI and core workflow primitives
- desktop app shell
- voice capture and transcription
- context builder
- agent adapters
- worktree runner
- diff/result UI
