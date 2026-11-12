import { test } from "node:test";
import assert from "node:assert/strict";
import { isCheckedFile, staleNames, type Known } from "./names.ts";

// The mod's globals and game tests, as the CLI reads them from the scripts and the harness's history
const known = (over: Partial<Known> = {}): Known => ({
  globals: new Set(["$APiratesLife_CaptureOps"]),
  tests: new Set(["claim_intact"]),
  retired: new Set(["old_bail_test"]),
  ...over,
});

test("a mod global the scripts don't have is reported with its line", () => {
  const text = "Intro\nThe flag `global.$APiratesLife_Gone` and `$APiratesLife_CaptureOps`.\n";

  assert.deepEqual(staleNames(text, known()), [
    { line: 2, name: "$APiratesLife_Gone", why: "isn't a mod global" },
  ]);
});

test("a retired game test, backticked or tagged, is reported; other snake_case isn't", () => {
  const text = [
    "Covered by `old_bail_test` and `claim_intact`.",
    "Tag scenarios with game tests (e.g. @old_bail_test).",
    "Patch `set_owner` and plain old_bail_test prose.",
  ].join("\n");

  assert.deepEqual(staleNames(text, known()), [
    { line: 1, name: "old_bail_test", why: "is a retired game test" },
    { line: 2, name: "old_bail_test", why: "is a retired game test" },
  ]);
});

test("a line marked as history is skipped: 9.x line, an issue link, or a ticked item", () => {
  const text = [
    "Sets `$APiratesLife_CaptureOps`; on the 9.x line also `$APiratesLife_Gone`.",
    "The `old_bail_test` test left with [#117](https://github.com/o/r/issues/117).",
    "Dropped `$APiratesLife_Gone` (see https://github.com/o/r/issues/117).",
    "- [x] Test `old_bail_test` in game",
    "- [ ] Test `old_bail_test` in game",
  ].join("\n");

  assert.deepEqual(staleNames(text, known()), [
    { line: 5, name: "old_bail_test", why: "is a retired game test" },
  ]);
});

test("the docs and tools are checked, but not records, 9.x-line docs, tests or fixtures", () => {
  const checked = ["README.md", "GLOSSARY.md", "docs/PROJECT.md", "docs/specs/capture-settings.md", "tools/README.md",
    "tools/check_test_plan.py", "tools/run-game-tests.ps1", "tools/check-doc-paths/paths.ts", "tools/worktree-status.sh"];
  const skipped = ["docs/research/booty.md", "docs/rejected/README.md", "docs/DESIGN.md", "docs/IMPLEMENTATION_PLAN.md",
    "docs/test-plan/bail-hook.md", "tools/check-doc-paths/paths.test.ts", "tools/diff-patches/fixtures/mod/md/script.xml",
    "md/apirateslife_config.xml", "tests/python/test_texts.py"];

  assert.deepEqual(checked.filter((path) => !isCheckedFile(path)), []);
  assert.deepEqual(skipped.filter(isCheckedFile), []);
});
