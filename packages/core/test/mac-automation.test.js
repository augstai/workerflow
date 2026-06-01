import assert from "node:assert/strict";
import test from "node:test";
import {
  assessMacOperatorToolCall,
  classifyShellCommand,
  containsRiskyText,
  getMacOperatorTool,
  listMacOperatorTools
} from "../src/mac-automation.js";

test("Mac operator registry exposes generic interface tools", () => {
  const tools = listMacOperatorTools().map((tool) => tool.name);

  assert.ok(tools.includes("get_active_app"));
  assert.ok(tools.includes("get_ax_tree"));
  assert.ok(tools.includes("get_screen"));
  assert.ok(tools.includes("click_element"));
  assert.ok(tools.includes("run_shell"));
  assert.ok(tools.includes("handoff_to_codex"));
});

test("Mac operator read-only tools do not require approval", () => {
  const decision = assessMacOperatorToolCall({ name: "get_ax_tree", args: { app: "Cursor" } });

  assert.equal(decision.allowed, true);
  assert.equal(decision.approvalRequired, false);
  assert.equal(decision.risk, "read-only");
});

test("Mac operator low-risk local actions can run without approval", () => {
  const decision = assessMacOperatorToolCall({ name: "open_app", args: { name: "Cursor" } });

  assert.equal(decision.allowed, true);
  assert.equal(decision.approvalRequired, false);
  assert.equal(decision.risk, "low");
});

test("Mac operator click and typing actions require approval", () => {
  const clickDecision = assessMacOperatorToolCall({ name: "click_element", args: { elementId: "button:Submit" } });
  const typeDecision = assessMacOperatorToolCall({ name: "type_text", args: { text: "hello" } });

  assert.equal(clickDecision.allowed, true);
  assert.equal(clickDecision.approvalRequired, true);
  assert.equal(typeDecision.allowed, true);
  assert.equal(typeDecision.approvalRequired, true);
});

test("Mac operator allows read-only shell inspection without approval", () => {
  const decision = assessMacOperatorToolCall({ name: "run_shell", args: { command: "du -sh ~/Downloads" } });

  assert.equal(decision.allowed, true);
  assert.equal(decision.approvalRequired, false);
  assert.equal(decision.risk, "read-only-shell");
});

test("Mac operator shell mutations require approval", () => {
  const decision = assessMacOperatorToolCall({ name: "run_shell", args: { command: "rm ~/Downloads/old.zip" } });

  assert.equal(decision.allowed, true);
  assert.equal(decision.approvalRequired, true);
  assert.match(decision.reason, /risky|approval/i);
});

test("Mac operator shell allowlist rejects control syntax", () => {
  const decision = classifyShellCommand("du -sh ~/Downloads | sort -h");

  assert.equal(decision.readOnly, false);
  assert.match(decision.reason, /control syntax/);
});

test("Mac operator blocks unknown tool names", () => {
  const decision = assessMacOperatorToolCall({ name: "magic_delete_everything", args: {} });

  assert.equal(getMacOperatorTool("magic_delete_everything"), null);
  assert.equal(decision.allowed, false);
  assert.equal(decision.risk, "blocked");
});

test("Mac operator detects risky language in args", () => {
  assert.equal(containsRiskyText("please empty trash and delete old files"), true);

  const decision = assessMacOperatorToolCall({ name: "set_clipboard", args: { text: "rm -rf ~/.cache" } });
  assert.equal(decision.approvalRequired, true);
});
