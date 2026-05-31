import assert from "node:assert/strict";
import test from "node:test";
import { makeWorktreePlan } from "../src/index.js";

test("makeWorktreePlan creates stable branch and path", () => {
  const plan = makeWorktreePlan({
    repoRoot: "/tmp/example",
    jobId: "job_123"
  });

  assert.equal(plan.branch, "workerflow/job_123");
  assert.equal(plan.path, "/tmp/example-workerflow-job_123");
});
