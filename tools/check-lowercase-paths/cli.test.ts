import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-lowercase-paths.ts", import.meta.url));

// A git repo in a temp folder with these files (some committed, the rest left untracked), run from
// its md/ folder
function run(files: Record<string, string>, ...args: string[]) {
  const root = mkdtempSync(join(tmpdir(), "lowercase-paths-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  mkdirSync(join(root, "md"), { recursive: true });
  spawnSync("git", ["init", "-q"], { cwd: root });
  spawnSync("git", ["add", "deploy.include"], { cwd: root });
  return spawnSync(process.execPath, [cli, ...args], { cwd: join(root, "md"), encoding: "utf8" });
}

test("the CLI names each uppercase shipped path, tracked or new, and exits 1", () => {
  const result = run({
    "deploy.include": "content.xml\nmd\nt\n",
    "content.xml": "",
    "md/Capture.xml": "",
    "t/0001-L044.xml": "",
    "docs/PROJECT.md": "",
    "build/Out.xml": "",
    ".gitignore": "md/Scratch.xml\n",
    "md/Scratch.xml": "",
  });

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "Lowercase paths: 2 shipped with uppercase letters (X4 expects lowercase)",
      "  md/Capture.xml",
      "  t/0001-L044.xml",
      "",
    ].join("\n"),
  );
});

test("the CLI says ok and exits 0 when every shipped path is lowercase", () => {
  const result = run({ "deploy.include": "md\n", "md/capture.xml": "", "README.md": "" });

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Lowercase paths: ok\n");
});

test("the CLI exits 2 with a usage line on an unknown option", () => {
  const result = run({ "deploy.include": "" }, "--bogus");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-lowercase-paths.ts\n$/);
});
