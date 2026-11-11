import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const tools = fileURLToPath(new URL("..", import.meta.url));

// A repo with the real CLI and module copied into its tools/, locking saxes 6.0.0
function fakeRepo(installed: string | undefined): string {
  const root = mkdtempSync(join(tmpdir(), "check-deps-cli-"));
  mkdirSync(join(root, "tools", "check-deps"), { recursive: true });
  copyFileSync(join(tools, "check-deps.ts"), join(root, "tools", "check-deps.ts"));
  copyFileSync(join(tools, "check-deps", "deps.ts"), join(root, "tools", "check-deps", "deps.ts"));
  writeFileSync(join(root, "package.json"), JSON.stringify({ type: "module", devDependencies: { saxes: "^6.0.0" } }));
  writeFileSync(
    join(root, "package-lock.json"),
    JSON.stringify({ lockfileVersion: 3, packages: { "node_modules/saxes": { version: "6.0.0" } } }),
  );
  if (installed) {
    mkdirSync(join(root, "node_modules", "saxes"), { recursive: true });
    writeFileSync(join(root, "node_modules", "saxes", "package.json"), JSON.stringify({ version: installed }));
  }
  return root;
}

const run = (root: string, ...args: string[]) =>
  spawnSync(process.execPath, [join(root, "tools", "check-deps.ts"), ...args], { encoding: "utf8" });

test("the CLI prints ok and exits 0 when node_modules matches the lock", () => {
  const result = run(fakeRepo("6.0.0"));

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Dependencies: ok\n");
});

test("the CLI names a missing package, says what to run, and exits 1", () => {
  const result = run(fakeRepo(undefined));

  assert.equal(result.status, 1);
  assert.equal(
    result.stderr,
    `node_modules doesn't match package-lock.json:
  saxes: not installed (package-lock.json has 6.0.0)
Run \`make setup\` in the main checkout (or \`npm install\` in this worktree if your branch changes package.json).
`,
  );
});

test("the CLI exits 2 with a usage line on an unknown option", () => {
  const result = run(fakeRepo("6.0.0"), "--bogus");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-deps.ts\n$/);
});
