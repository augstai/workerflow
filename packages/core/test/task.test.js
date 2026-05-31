import assert from "node:assert/strict";
import test from "node:test";
import { classifyTask, cleanSpokenCommand } from "../src/index.js";

test("cleanSpokenCommand removes common filler", () => {
  assert.equal(cleanSpokenCommand("uh fix like this test"), "Fix this test");
});

test("classifyTask separates dictation from action", () => {
  assert.equal(classifyTask("write a reply saying Friday works").mode, "dictation");
  assert.equal(classifyTask("fix the failing auth test").mode, "action");
});
