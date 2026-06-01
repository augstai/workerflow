# Mac Operator Mode

Workerflow should support a full Mac operator mode as an option, while preserving the original coding-agent workflow as its strongest lane.

The product promise:

```text
hold hotkey -> speak -> release -> Workerflow decides direct action vs assisted Mac task vs coding-agent handoff
```

Examples:

- "Find opportunities on this Mac to reduce storage utilization."
- "Help me fill out this questionnaire using the info you have."
- "Find restaurants to go to tomorrow with my friends."
- "Write tests for this codebase."

## Product Modes

### 1. Direct Mac Action

Small, safe tasks that Workerflow can do locally without handing off to a coding agent.

Examples:

- open Cursor or Terminal
- copy selected text and rewrite it
- paste a drafted response into the active field
- open a file, folder, app, URL, or Shortcut
- summarize the visible terminal error

### 2. Guided Mac Operator

Tasks that need screen context, Accessibility tree inspection, clipboard, shell reads, or multiple desktop steps.

Examples:

- inspect disk usage through generic shell/filesystem context and propose cleanup candidates
- fill a browser questionnaire from known profile/context
- collect restaurant options from browser/search tools
- navigate an app UI using Accessibility when available and coordinates only as fallback

This mode should be visible, interruptible, and approval-gated. The model should not silently click through high-impact actions.

### 3. Coding-Agent Handoff

Tasks that need codebase reasoning, edits, tests, or patch review.

Examples:

- write tests
- fix a bug
- refactor a module
- run verification commands
- summarize a diff

These jobs continue to run in isolated worktrees and return artifacts, verification, and apply/reject controls.

## Router

The router should classify every spoken command into one route:

```text
voice transcript
  -> cleanup
  -> intent/router
  -> direct action | guided Mac operator | coding-agent handoff | ask clarification
```

Routing should use conservative defaults:

- code edits -> coding-agent handoff
- file deletion / cleanup -> guided review before action
- external submission / purchase / message sending -> explicit approval
- browser research -> guided operator with citations/source notes when useful
- simple local UI commands -> direct Mac action

## Local Tool Surfaces

Workerflow should expose these as a local tool layer, not as ad hoc UI code.

### Perception Tools

- `get_active_app()`
- `get_windows()`
- `get_ax_tree({ app, windowId })`
- `get_screen({ display, region })`
- `get_selected_text()`
- `get_clipboard()`
- `get_frontmost_url()`
- `get_repo_context()`

### Action Tools

- `open_app({ name })`
- `focus_window({ app, titleIncludes })`
- `click_element({ elementId })`
- `press_button({ app, label })`
- `click({ x, y })`
- `type_text({ text })`
- `hotkey({ keys })`
- `scroll({ amount })`
- `set_clipboard({ text })`
- `replace_selection({ text })`
- `run_shortcut({ name })`
- `run_applescript({ script })`
- `run_shell({ command })`

### Coding Tools

- `create_worktree({ task })`
- `handoff_to_codex({ task })`
- `handoff_to_claude_code({ task })`
- `run_tests()`
- `open_diff()`
- `apply_patch_after_review()`
- `reject_job()`

## Safety Policy

Desktop control is powerful. The tool layer must enforce policy before the model can act.

Always require approval for:

- deleting files or emptying Trash
- sending forms, emails, messages, comments, reviews, or issues
- purchases, bookings, reservations, subscriptions, or anything that spends money
- running shell commands that are destructive, privileged, networked, or long-running
- installing software or changing system settings
- granting permissions
- applying code changes to the main checkout

Prefer dry-run/review first:

- storage tasks should use generic inspection tools to produce a candidate list before deletion
- questionnaires should fill drafts before final submit
- restaurants should produce options before booking
- code tasks should produce diffs before apply

## Permissions

Required for voice:

- Microphone
- Accessibility for global push-to-talk

Optional for operator mode:

- Screen Recording for screen context
- Screen Content probe for confirming ScreenCaptureKit works
- Accessibility for UI tree and element actions
- Input Monitoring if low-level keyboard observation/action requires it in signed builds
- Automation for AppleScript/System Events control of other apps
- Files/Folders or Full Disk Access only when the user explicitly wants broad local file inspection

Screen context must remain optional. Voice capture must work without it.

## Example Flows

### Storage Cleanup

```text
User: find opportunities on this Mac to reduce storage utilization
Workerflow:
  1. lets the agent inspect disk usage with safe shell/filesystem tools
  2. has the agent identify large caches, downloads, build artifacts, and old job folders
  3. shows candidates with size and risk
  4. asks approval before deleting anything
```

### Questionnaire

```text
User: help me fill this questionnaire
Workerflow:
  1. reads focused app, page text, selected fields, and optional screen context
  2. drafts field values from user-approved profile/project context
  3. fills fields via Accessibility or clipboard
  4. asks before final submission
```

### Restaurants

```text
User: find restaurants tomorrow for me and my friends
Workerflow:
  1. asks for missing constraints if needed
  2. searches or opens browser/app sources through configured tools
  3. compares options, location, hours, availability, and vibe
  4. asks before booking or messaging anyone
```

### Codebase Tests

```text
User: write tests for this codebase
Workerflow:
  1. captures repo context
  2. creates isolated worktree
  3. hands off to Codex/Claude Code
  4. runs verification
  5. returns diff and apply/reject controls
```

## Commercial Shape

Initial pricing can be tested as:

- free trial for activation and trust-building
- monthly: $10
- annual: $50
- lifetime: $100

Paid features should map to real value:

- realtime operator mode
- hosted model/proxy usage
- richer desktop automation
- coding-agent monitoring and review surface
- sync of non-secret preferences and approved profile context

Foundational local coding-agent features should stay useful without requiring networked services in tests.

## Implementation Order

1. Finish native voice/screen foundation and gallery.
2. Add a local `MacAutomationService` protocol with mocked tests.
3. Implement read-only perception tools first: active app, windows, selected text, clipboard, screen, AX tree.
4. Add direct safe actions: open app, focus window, set clipboard, paste, hotkey.
5. Add approval-gated actions: click element, type into field, shell, AppleScript, Shortcuts.
6. Add router: direct action vs guided operator vs coding-agent handoff.
7. Add realtime provider behind explicit config.
8. Add signed-app TCC and end-to-end tests for the operator loop.
