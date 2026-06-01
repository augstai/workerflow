# Roadmap

## v0.1: Foundation

- CLI package
- repo attach/status
- config file
- context capture
- safety defaults
- prompt generation
- project docs and CI

## v0.2: Agent Runner

- adapter interface
- Codex CLI adapter
- Claude Code adapter
- worktree creation
- job logs and result files
- CLI doctor/run/job inspection

## v0.3: Desktop Shell

- native Swift/AppKit menu-bar app
- Electron prototype fallback
- menu bar state
- native macOS hold-to-talk monitor as preferred path
- listen-only hotkey transition handling with repeat suppression
- compact command pill
- separate review/result surface
- permission setup and recovery panel
- local notifications
- job list UI

## v0.4: Voice Pipeline

- microphone permission flow
- transcription provider abstraction
- standalone transcription test
- real audio-level telemetry for recording waveform
- command cleanup
- dictation vs action classifier
- compact risk confirmation

## v0.5: Demo-Ready Product

- diff viewer
- apply/reject workflow
- status notification
- result summary
- 60-second demo script
- install docs
- native debug logs and redacted diagnostics bundles

## v0.6: Mac Operator Foundation

- product router for direct action vs guided operator vs coding-agent handoff
- mockable `MacAutomationService` interface
- read-only active app/window context
- read-only Accessibility tree extraction
- selected text and clipboard tools
- safe `open_app`, focus window, and clipboard replacement actions
- approval model for desktop-control tools
- native gallery states for direct action, guided operator, and approval loops

## v0.7: Guided Operator Mode

- ScreenCaptureKit context in operator loop
- generic desktop and shell inspection tools that let agents propose cleanup candidates with review-before-delete
- questionnaire-fill workflow with draft-before-submit
- browser/research workflow with explicit booking/sending approvals
- AppleScript and Shortcuts adapters behind policy
- coordinate click fallback only when Accessibility cannot act
- signed-app TCC checklist for Screen Recording, Accessibility, Automation, and Input Monitoring

## v0.8: Realtime + Commercial Beta

- optional realtime provider behind explicit config
- low-latency voice loop with tool-call events
- local event stream from operator/agent runner into native UI
- free trial/licensing hooks
- pricing experiment: monthly, annual, lifetime
- hosted proxy only for configured paid/realtime features

## Later

- mouse-following screen context overlay
- screen-pointing coordinate pipeline
- local transcription
- Aider adapter
- custom command adapter
- VS Code/Cursor integration
- GitHub issue/PR draft flows
- team policy configs
- hosted sync for approved metadata
