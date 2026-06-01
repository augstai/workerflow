export const MAC_OPERATOR_TOOLS = Object.freeze([
  {
    name: "get_active_app",
    kind: "perception",
    approval: "none",
    description: "Return the frontmost macOS application."
  },
  {
    name: "get_windows",
    kind: "perception",
    approval: "none",
    description: "Return visible macOS windows and frames."
  },
  {
    name: "get_ax_tree",
    kind: "perception",
    approval: "none",
    description: "Return an Accessibility tree snapshot for a target app or window."
  },
  {
    name: "get_selected_text",
    kind: "perception",
    approval: "none",
    description: "Return selected text from the focused UI element when available."
  },
  {
    name: "get_clipboard",
    kind: "perception",
    approval: "none",
    description: "Return plain text from the clipboard."
  },
  {
    name: "get_screen",
    kind: "perception",
    approval: "none",
    description: "Return optional ScreenCaptureKit display context."
  },
  {
    name: "open_app",
    kind: "action",
    approval: "low-risk",
    description: "Open a local application by name or bundle identifier."
  },
  {
    name: "focus_window",
    kind: "action",
    approval: "low-risk",
    description: "Bring an existing app/window to the front."
  },
  {
    name: "set_clipboard",
    kind: "action",
    approval: "low-risk",
    description: "Set plain text on the clipboard without pasting it."
  },
  {
    name: "hotkey",
    kind: "action",
    approval: "policy",
    description: "Press a keyboard shortcut."
  },
  {
    name: "click_element",
    kind: "action",
    approval: "policy",
    description: "Click an Accessibility element by stable element id."
  },
  {
    name: "press_button",
    kind: "action",
    approval: "policy",
    description: "Press a UI button by app/label when Accessibility can resolve it."
  },
  {
    name: "click",
    kind: "action",
    approval: "policy",
    description: "Coordinate click fallback when semantic UI control is unavailable."
  },
  {
    name: "type_text",
    kind: "action",
    approval: "policy",
    description: "Type text into the focused UI element."
  },
  {
    name: "replace_selection",
    kind: "action",
    approval: "policy",
    description: "Replace the selected text through clipboard or accessibility."
  },
  {
    name: "run_shortcut",
    kind: "action",
    approval: "policy",
    description: "Run an Apple Shortcut."
  },
  {
    name: "run_applescript",
    kind: "action",
    approval: "policy",
    description: "Run AppleScript or System Events automation."
  },
  {
    name: "run_shell",
    kind: "action",
    approval: "policy",
    description: "Run a local shell command."
  },
  {
    name: "handoff_to_codex",
    kind: "handoff",
    approval: "policy",
    description: "Create a Workerflow job and hand the task to Codex CLI."
  },
  {
    name: "handoff_to_claude_code",
    kind: "handoff",
    approval: "policy",
    description: "Create a Workerflow job and hand the task to Claude Code."
  }
]);

const TOOL_BY_NAME = new Map(MAC_OPERATOR_TOOLS.map((tool) => [tool.name, tool]));

const ALWAYS_APPROVAL_TOOLS = new Set([
  "click_element",
  "press_button",
  "click",
  "type_text",
  "replace_selection",
  "run_shortcut",
  "run_applescript"
]);

const READ_ONLY_SHELL_COMMANDS = new Set([
  "cat",
  "df",
  "du",
  "file",
  "find",
  "head",
  "ls",
  "mdfind",
  "mdls",
  "plutil",
  "pwd",
  "stat",
  "sw_vers",
  "system_profiler",
  "tail",
  "uname",
  "wc",
  "whoami"
]);

const READ_ONLY_GIT_SUBCOMMANDS = new Set([
  "branch",
  "diff",
  "log",
  "ls-files",
  "rev-parse",
  "show",
  "status"
]);

const SENSITIVE_HOTKEYS = [
  ["cmd", "q"],
  ["cmd", "w"],
  ["cmd", "delete"],
  ["cmd", "shift", "delete"],
  ["cmd", "enter"],
  ["enter"]
];

const RISKY_TEXT_PATTERNS = [
  /\brm\s+-rf\b/i,
  /\brm\b/i,
  /\brmdir\b/i,
  /\bunlink\b/i,
  /\bsudo\b/i,
  /\bchmod\s+[-+]?R?\b/i,
  /\bchown\s+[-+]?R?\b/i,
  /\bmv\s+.+\s+\/dev\/null\b/i,
  /\bcp\s+-R\b/i,
  /\btrash\b/i,
  /\bdelete\b/i,
  /\bempty\s+trash\b/i,
  /\bsubmit\b/i,
  /\bsend\b/i,
  /\bpost\b/i,
  /\bbook\b/i,
  /\breserve\b/i,
  /\bpurchase\b/i,
  /\bpay\b/i,
  /\bsubscribe\b/i,
  /\bdeploy\b/i,
  /\bcurl\b/i,
  /\bwget\b/i,
  /\bssh\b/i,
  /\bscp\b/i,
  /\brsync\b/i,
  /(^|\s)(?:bash|zsh|sh)(\s|$)/i,
  /\bosascript\b/i,
  /\bgit\s+push\b/i,
  /\bgit\s+merge\b/i,
  /\bkill(all)?\b/i
];

const SHELL_CONTROL_PATTERN = /[;&|<>`]|\$\(|\${|\n/;

export function getMacOperatorTool(name) {
  return TOOL_BY_NAME.get(name) ?? null;
}

export function listMacOperatorTools() {
  return MAC_OPERATOR_TOOLS;
}

export function assessMacOperatorToolCall({ name, args = {} }) {
  const tool = getMacOperatorTool(name);
  if (!tool) {
    return {
      allowed: false,
      approvalRequired: false,
      risk: "blocked",
      reason: `Unknown Mac operator tool: ${name}`
    };
  }

  if (tool.kind === "perception") {
    return {
      allowed: true,
      approvalRequired: false,
      risk: "read-only",
      reason: "Read-only perception tool."
    };
  }

  if (tool.approval === "low-risk" && !containsRiskyText(JSON.stringify(args))) {
    return {
      allowed: true,
      approvalRequired: false,
      risk: "low",
      reason: "Low-risk local action."
    };
  }

  if (name === "hotkey" && isLowRiskHotkey(args.keys)) {
    return {
      allowed: true,
      approvalRequired: false,
      risk: "low",
      reason: "Low-risk hotkey."
    };
  }

  if (name === "run_shell") {
    const shellDecision = classifyShellCommand(args.command ?? args.cmd ?? "");
    if (shellDecision.readOnly) {
      return {
        allowed: true,
        approvalRequired: false,
        risk: "read-only-shell",
        reason: shellDecision.reason
      };
    }

    return {
      allowed: true,
      approvalRequired: true,
      risk: "approval",
      reason: shellDecision.reason
    };
  }

  if (ALWAYS_APPROVAL_TOOLS.has(name) || containsRiskyText(JSON.stringify(args))) {
    return {
      allowed: true,
      approvalRequired: true,
      risk: "approval",
      reason: approvalReason(name, args)
    };
  }

  return {
    allowed: true,
    approvalRequired: true,
    risk: "approval",
    reason: "Action requires user approval."
  };
}

export function containsRiskyText(text = "") {
  return RISKY_TEXT_PATTERNS.some((pattern) => pattern.test(text));
}

export function classifyShellCommand(command = "") {
  const normalized = String(command).trim();
  if (!normalized) {
    return {
      readOnly: false,
      reason: "Shell command is empty."
    };
  }

  if (SHELL_CONTROL_PATTERN.test(normalized)) {
    return {
      readOnly: false,
      reason: "Shell command uses shell control syntax and requires approval."
    };
  }

  if (containsRiskyText(normalized)) {
    return {
      readOnly: false,
      reason: "Shell command contains risky or external-action language."
    };
  }

  const [binary, subcommand] = normalized.split(/\s+/, 2);
  const commandName = basename(binary);

  if (commandName === "git") {
    if (READ_ONLY_GIT_SUBCOMMANDS.has(subcommand)) {
      return {
        readOnly: true,
        reason: "Read-only git inspection command."
      };
    }

    return {
      readOnly: false,
      reason: "Git command is not an approved read-only inspection command."
    };
  }

  if (READ_ONLY_SHELL_COMMANDS.has(commandName)) {
    return {
      readOnly: true,
      reason: "Read-only local inspection command."
    };
  }

  return {
    readOnly: false,
    reason: "Shell command is not in the read-only inspection allowlist."
  };
}

function isLowRiskHotkey(keys = []) {
  if (!Array.isArray(keys) || keys.length === 0) {
    return false;
  }

  const normalized = keys.map((key) => String(key).toLowerCase()).sort();
  return !SENSITIVE_HOTKEYS.some((sensitive) => {
    const sortedSensitive = [...sensitive].sort();
    return sortedSensitive.length === normalized.length
      && sortedSensitive.every((key, index) => key === normalized[index]);
  });
}

function basename(commandName = "") {
  return String(commandName).split("/").filter(Boolean).pop() ?? "";
}

function approvalReason(name, args) {
  if (name === "run_shell") {
    return classifyShellCommand(args.command ?? args.cmd ?? "").reason;
  }
  if (name === "run_applescript" || name === "run_shortcut") {
    return "System automation can control other apps and submit user-visible actions.";
  }
  if (name === "click" || name === "click_element" || name === "press_button") {
    return "Clicking can submit forms, confirm dialogs, or trigger app actions.";
  }
  if (name === "type_text" || name === "replace_selection") {
    return "Typing can modify user content in the focused app.";
  }
  if (containsRiskyText(JSON.stringify(args))) {
    return "The requested action contains risky or external-action language.";
  }
  return "Action requires user approval.";
}
