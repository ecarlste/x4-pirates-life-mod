import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-debug-tags.ts", import.meta.url));

// A git repo in a temp folder with these files (md/capture.xml committed, the rest left
// untracked), run from its md/ folder
function run(files: Record<string, string>, ...args: string[]) {
  const root = mkdtempSync(join(tmpdir(), "debug-tags-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  mkdirSync(join(root, "md"), { recursive: true });
  spawnSync("git", ["init", "-q"], { cwd: root });
  spawnSync("git", ["add", "md"], { cwd: root });
  return spawnSync(process.execPath, [cli, ...args], { cwd: join(root, "md"), encoding: "utf8" });
}

test("the CLI names each probe tag left in a shipped or game-test file, tracked or new, and exits 1", () => {
  const result = run({
    "md/capture.xml": "<cue>\n  <debug_text text=\"'[DEBUG-h1] hull'\" />\n</cue>\n",
    "aiscripts/fight.xml": "ok\n",
    "libraries/jobs.xml": "[DEBUG-p1]\n",
    "t/0001-l044.xml": "ok\n",
    "tests/game/apirateslife_tests/md/apirateslife_tests.xml": "\n\n[DEBUG-x] probe\n",
    "tests/game/README.md": "",
    "docs/testing.md": "Tags look like [DEBUG-h1].\n",
    "tools/check.ts": "const TAG = '[DEBUG-';\n",
    "mdx/notes.xml": "[DEBUG-h2]\n",
    ".gitignore": "md/scratch.xml\n",
    "md/scratch.xml": "[DEBUG-h3]\n",
  });

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "Debug tags: 3 probe tags left in (remove each [DEBUG-…] probe once the bug is found)",
      "  libraries/jobs.xml:1: [DEBUG-p1]",
      `  md/capture.xml:2: <debug_text text="'[DEBUG-h1] hull'" />`,
      "  tests/game/apirateslife_tests/md/apirateslife_tests.xml:3: [DEBUG-x] probe",
      "",
    ].join("\n"),
  );
});

test("the CLI says ok and exits 0 when no probe tag is left", () => {
  const result = run({ "md/capture.xml": "ok\n", "docs/testing.md": "[DEBUG-h1]\n" });

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Debug tags: ok\n");
});

test("the CLI exits 2 with a usage line on an unknown option", () => {
  const result = run({}, "--bogus");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-debug-tags.ts\n$/);
});

test("the CLI skips a tracked file deleted in the working tree", () => {
  const root = mkdtempSync(join(tmpdir(), "debug-tags-"));
  mkdirSync(join(root, "md"));
  writeFileSync(join(root, "md/old.xml"), "ok\n");
  spawnSync("git", ["init", "-q"], { cwd: root });
  spawnSync("git", ["add", "md"], { cwd: root });
  rmSync(join(root, "md/old.xml"));
  const result = spawnSync(process.execPath, [cli], { cwd: root, encoding: "utf8" });

  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "Debug tags: ok\n");
});
