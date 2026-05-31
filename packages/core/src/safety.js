export const DEFAULT_SAFETY_RULES = Object.freeze([
  "Do not push commits or branches.",
  "Do not merge pull requests.",
  "Do not deploy to production.",
  "Do not edit .env or credential files.",
  "Do not run destructive file operations without approval.",
  "Do not spend money or call paid external services without approval.",
  "Use a git worktree for code-changing tasks when configured.",
  "Show a diff before applying changes to the user's main checkout."
]);

const APPROVAL_PATTERNS = [
  /\bgit\s+push\b/i,
  /\bgit\s+merge\b/i,
  /\bdeploy\b/i,
  /\brm\s+-rf\b/i,
  /\bmigration(s)?\b/i,
  /(^|\s)\.env(\s|$)/i,
  /\bpayment(s)?\b/i,
  /\bauth\b/i
];

export function requiresApproval(text) {
  return APPROVAL_PATTERNS.some((pattern) => pattern.test(text));
}

export function formatSafetyRules() {
  return DEFAULT_SAFETY_RULES.map((rule) => `- ${rule}`).join("\n");
}
