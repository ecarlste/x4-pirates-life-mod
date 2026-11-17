import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-pr-branch.ts", import.meta.url));

const run = (...args: string[]) => spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });

test("a PR from a research/ branch fails, saying the work belongs on an issue-<n> branch", () => {
  const result = run("research/x");

  assert.equal(result.status, 1);
  assert.match(result.stdout, /^::error::/);
  assert.match(result.stdout, /research\/x holds research and is never merged/);
  assert.match(result.stdout, /issue-<n> branch/);
});

test("a PR from a prototype/ branch fails too", () => {
  const result = run("prototype/x");

  assert.equal(result.status, 1);
  assert.match(result.stdout, /prototype\/x holds a prototype and is never merged/);
});

test("a PR from issue-12, or any other name, passes", () => {
  for (const branch of ["issue-12", "feature/thing", "research-notes", "my-research/x"]) {
    const result = run(branch);

    assert.equal(result.status, 0, branch);
    assert.equal(result.stdout, `OK: ${branch}\n`);
  }
});

test("no branch exits 2 with a usage line", () => {
  const result = run();

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-pr-branch\.ts <branch>/);
});
