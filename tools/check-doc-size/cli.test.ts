import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const tools = fileURLToPath(new URL("..", import.meta.url));

// A repo with the real CLI copied into its tools/ and a docs/PROJECT.md of the given size in bytes
function fakeRepo(projectBytes: number): string {
  const root = mkdtempSync(join(tmpdir(), "check-doc-size-cli-"));
  mkdirSync(join(root, "tools"));
  mkdirSync(join(root, "docs"));
  copyFileSync(join(tools, "check-doc-size.ts"), join(root, "tools", "check-doc-size.ts"));
  writeFileSync(join(root, "docs", "PROJECT.md"), "x".repeat(projectBytes));
  return root;
}

const run = (root: string, ...args: string[]) =>
  spawnSync(process.execPath, [join(root, "tools", "check-doc-size.ts"), ...args], { encoding: "utf8" });

test("PROJECT.md at the 8 KB budget passes", () => {
  const result = run(fakeRepo(8192));

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Doc size: ok (docs/PROJECT.md 8192 of 8192 bytes)\n");
});

test("PROJECT.md over the budget fails, saying to move detail out rather than raise the limit", () => {
  const result = run(fakeRepo(8193));

  assert.equal(result.status, 1);
  assert.match(result.stdout, /docs\/PROJECT\.md is 8193 bytes, over its budget of 8192/);
  assert.match(result.stdout, /"Where to look" table/);
  assert.match(result.stdout, /rather than raising the budget/);
});

test("the size counts bytes, not characters", () => {
  const root = fakeRepo(0);
  writeFileSync(join(root, "docs", "PROJECT.md"), "é".repeat(4097)); // 8194 bytes in UTF-8

  assert.equal(run(root).status, 1);
});

test("an unknown option exits 2 with a usage line", () => {
  const result = run(fakeRepo(10), "--nope");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-doc-size\.ts/);
});
