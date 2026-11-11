import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-diff-patches.ts", import.meta.url));
const missing = fileURLToPath(new URL("fixtures/no-such-folder", import.meta.url));

const run = (...args: string[]) =>
  spawnSync(process.execPath, [cli, ...args], {
    encoding: "utf8",
    env: { ...process.env, X4_UNPACKED: missing, SWI_UNPACKED: missing },
  });

test("the CLI skips with a note and exits 0 when the unpacked files aren't there, as in CI", () => {
  const result = run();

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Diff patches: ok\n  not checked: X4_UNPACKED not found\n");
});

test("the CLI exits 2 with a usage line on an unknown option", () => {
  const result = run("--bogus");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-diff-patches.ts \[--verbose\]\n$/);
});
