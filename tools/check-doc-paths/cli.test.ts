import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-doc-paths.ts", import.meta.url));

// A git repo in a temp folder with these files, run from its docs/ folder
function run(files: Record<string, string>, ...args: string[]) {
  const root = mkdtempSync(join(tmpdir(), "doc-paths-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  mkdirSync(join(root, "docs"), { recursive: true });
  spawnSync("git", ["init", "-q"], { cwd: root });
  return spawnSync(process.execPath, [cli, ...args], { cwd: join(root, "docs"), encoding: "utf8" });
}

test("the CLI names each missing path by doc and line and exits 1", () => {
  const result = run({
    "docs/PROJECT.md": "Read [the design](DESIGN.md).\nDeploy with `deploy.sh`; stubs in `tests/lua/x4stubs.lua`.\n",
    "docs/test-plan/README.md": "Generated: `tests/gone.ts`\n",
    "tools/README.md": "`../deploy.config` is made by make setup\n",
    "README.md": "See `docs/PROJECT.md`, `GLOSSARY.md`, `tools/check.ts`.\n",
    ".gitignore": "deploy.config\n",
    "deploy.sh": "",
  });

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "Doc paths: 4 missing",
      "  README.md:1: GLOSSARY.md doesn't exist",
      "  README.md:1: tools/check.ts doesn't exist",
      "  docs/PROJECT.md:1: docs/DESIGN.md doesn't exist",
      "  docs/PROJECT.md:2: tests/lua/x4stubs.lua doesn't exist",
      "",
    ].join("\n"),
  );
});

test("the CLI says ok and exits 0 when every path exists", () => {
  const result = run({ "README.md": "See `docs/PROJECT.md`.\n", "docs/PROJECT.md": "" });

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Doc paths: ok\n");
});

test("the CLI exits 2 with a usage line on an unknown option", () => {
  const result = run({ "README.md": "" }, "--bogus");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-doc-paths.ts\n$/);
});
