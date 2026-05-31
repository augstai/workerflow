import assert from "node:assert/strict";
import test from "node:test";
import { requiresApproval } from "../src/index.js";

test("requiresApproval catches external or risky actions", () => {
  assert.equal(requiresApproval("git push origin main"), true);
  assert.equal(requiresApproval("deploy this to prod"), true);
  assert.equal(requiresApproval("edit the .env file"), true);
});

test("requiresApproval allows ordinary local tasks", () => {
  assert.equal(requiresApproval("fix this failing unit test"), false);
  assert.equal(requiresApproval("explain this stack trace"), false);
});
