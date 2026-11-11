// The mechanical rules for tools/, listed in tools/README.md's Rules section. Each rule is a function
// over a folder that returns one line per breach, naming the file and the rule; each is tested on a
// planted breach in a temp folder, then run on the repo.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const tools = join(root, "tools");

// This file checks tools/ as a whole, so it's the one test that sits loose in tools/
const SELF = "standards.test.ts";

const readIn = (dir: string, path: string) => readFileSync(join(dir, path), "utf8");

// .ts files anywhere under a tools/ folder, relative to it, sorted
const tsFiles = (dir: string): string[] =>
  readdirSync(dir, { recursive: true, encoding: "utf8" })
    .filter((path) => path.endsWith(".ts") && !path.split("/").includes("node_modules"))
    .sort();

// Files (not folders) directly in a tools/ folder, sorted
const looseFiles = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .sort();

// A CLI uses parseArgs (with the argv rule, every CLI does), however it imports it
const isCli = (path: string, source: string): boolean => !path.endsWith(".test.ts") && /\bparseArgs\b/.test(source);

// Rule: a repo's package.json devDependencies use ^ ranges
function caretProblems(repo: string): string[] {
  const pkg: { devDependencies?: Record<string, string> } = JSON.parse(readIn(repo, "package.json"));
  return Object.entries(pkg.devDependencies ?? {})
    .filter(([, range]) => !range.startsWith("^"))
    .map(([name, range]) => `package.json: ${name} is ${range}; use a ^ range (package-lock.json pins)`);
}

// Rule: no .ts file under tools/ reads the global's argv property, however it's spaced. The regex
// would match a literal read in this file too, so the tests here build that text by joining.
const ARGV = /\bprocess\s*\.\s*argv\b/;
const argvProblems = (dir: string): string[] =>
  tsFiles(dir)
    .filter((path) => ARGV.test(readIn(dir, path)))
    .map((path) => `tools/${path}: reads process arguments by hand; use parseArgs from node:util`);

// Rule: every CLI under tools/ exits 2 with a Usage: line on stderr for an unknown option
function cliProblems(dir: string): string[] {
  return tsFiles(dir)
    .filter((path) => isCli(path, readIn(dir, path)))
    .flatMap((path) => {
      const result = spawnSync(process.execPath, [join(dir, path), "--no-such-option"], { encoding: "utf8", timeout: 30_000 });
      const problems = [];
      if (result.status !== 2) problems.push(`exits ${result.status ?? result.signal}, not 2`);
      if (!result.stderr.includes("Usage:")) problems.push("prints no Usage: line to stderr");
      return problems.length ? [`tools/${path}: on an unknown option ${problems.join(" and ")}`] : [];
    });
}

// Rule: only CLIs sit directly in tools/; a module or a test belongs in its tool's folder
const looseModules = (dir: string): string[] =>
  looseFiles(dir)
    .filter((name) => name.endsWith(".ts") && name !== SELF && !isCli(name, readIn(dir, name)))
    .map((name) => `tools/${name}: a ${name.endsWith(".test.ts") ? "test" : "module"} loose in tools/; move it into its tool's folder`);

// The files tools/README.md's table lists: each table row's first cell links its file
const README_ROW = /^\|\s*\[[^\]]*\]\(([^)]+)\)\s*\|/;
const readmeRows = (dir: string): string[] =>
  readIn(dir, "README.md")
    .split("\n")
    .flatMap((line) => line.match(README_ROW)?.[1] ?? []);

// Rule: every file directly in tools/ has a row in tools/README.md's table, and every row names a file there
function readmeTableProblems(dir: string): string[] {
  const rows = readmeRows(dir);
  const files = looseFiles(dir).filter((name) => name !== "README.md");
  return [
    ...files.filter((name) => !rows.includes(name)).map((name) => `tools/${name}: no row in the tools/README.md table`),
    ...rows
      .filter((name) => !files.includes(name))
      .map((name) => `tools/${name}: a row in the tools/README.md table, but no such file in tools/`),
  ];
}

// A folder in a temp dir with these files in it (a name with a / makes its folder)
function plant(files: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "standards-"));
  for (const [name, content] of Object.entries(files)) {
    if (name.includes("/")) mkdirSync(join(dir, name, ".."), { recursive: true });
    writeFileSync(join(dir, name), content);
  }
  return dir;
}

const CLI = 'import { parseArgs } from "node:util";\ntry { parseArgs({ options: {} }); } catch { console.error("Usage: x"); process.exit(2); }\n';

test("caretProblems names a pinned or tilde devDependency", () => {
  const pkg = { devDependencies: { a: "^1.0.0", b: "1.0.0", c: "~2.0.0" } };
  assert.deepEqual(caretProblems(plant({ "package.json": JSON.stringify(pkg) })), [
    "package.json: b is 1.0.0; use a ^ range (package-lock.json pins)",
    "package.json: c is ~2.0.0; use a ^ range (package-lock.json pins)",
  ]);
  assert.deepEqual(caretProblems(plant({ "package.json": "{}" })), []);
});

test("every devDependency in package.json uses a ^ range", () => {
  assert.deepEqual(caretProblems(root), []);
});

test("argvProblems names a .ts file that reads the global's argv, however it's spaced", () => {
  const dir = plant({
    "a.ts": `const [x] = ${["process", "argv"].join(".")}.slice(2);`,
    "tool/b.ts": `if (${["process ", "argv"].join(".")}[1]) {}`,
    "c.ts": CLI,
  });
  assert.deepEqual(argvProblems(dir), [
    "tools/a.ts: reads process arguments by hand; use parseArgs from node:util",
    "tools/tool/b.ts: reads process arguments by hand; use parseArgs from node:util",
  ]);
});

test("no .ts file under tools/ reads process arguments by hand", () => {
  assert.deepEqual(argvProblems(tools), [], "Use import.meta.main to tell a CLI run from an import.");
});

test("isCli takes non-test files that use parseArgs", () => {
  const source = 'import { parseArgs } from "node:util";';
  assert.ok(isCli("tools/a.ts", source));
  assert.ok(isCli("tools/a.ts", 'import * as util from "node:util";\nutil.parseArgs({});'));
  assert.ok(!isCli("tools/a.test.ts", source));
  assert.ok(!isCli("tools/a.ts", 'import { format } from "node:util";'));
});

test("cliProblems names a CLI that lets parseArgs throw", () => {
  const dir = plant({
    "uncaught.ts": 'import { parseArgs } from "node:util";\nparseArgs({ options: {} });\n',
    "tool/caught.ts": CLI,
  });
  assert.deepEqual(cliProblems(dir), ["tools/uncaught.ts: on an unknown option exits 1, not 2 and prints no Usage: line to stderr"]);
});

test("every CLI under tools/ exits 2 with a Usage: line on an unknown option", () => {
  assert.ok(tsFiles(tools).some((path) => isCli(path, readIn(tools, path))), "found no CLIs");
  assert.deepEqual(cliProblems(tools), [], "Catch the error parseArgs throws, print a usage line to stderr and exit 2, as tools/check-deps.ts does.");
});

test("looseModules names a module or a test loose in tools/, not a CLI, a tool folder's files or this file", () => {
  const dir = plant({
    "cli.ts": CLI,
    "x.ts": "export const x = 1;\n",
    "x.test.ts": 'import { test } from "node:test";\n',
    [SELF]: "",
    "tool/mod.ts": "export const y = 2;\n",
    "tool/mod.test.ts": "",
    "run.sh": "",
  });
  assert.deepEqual(looseModules(dir), [
    "tools/x.test.ts: a test loose in tools/; move it into its tool's folder",
    "tools/x.ts: a module loose in tools/; move it into its tool's folder",
  ]);
});

test("every .ts file directly in tools/ is a CLI", () => {
  assert.deepEqual(looseModules(tools), []);
});

test("readmeTableProblems names a file with no row and a row with no file", () => {
  const dir = plant({
    "README.md": [
      "| Script | What it does |",
      "| --- | --- |",
      "| [`listed.py`](listed.py) | Listed, see [the note](../docs/note.md) |",
      "| [`gone.ps1`](gone.ps1) | Removed |",
      "",
      "Not a row: [`other.sh`](other.sh)",
    ].join("\n"),
    "listed.py": "",
    "unlisted.ts": CLI,
    "other.sh": "",
    "tool/mod.ts": "",
  });
  assert.deepEqual(readmeTableProblems(dir), [
    "tools/other.sh: no row in the tools/README.md table",
    "tools/unlisted.ts: no row in the tools/README.md table",
    "tools/gone.ps1: a row in the tools/README.md table, but no such file in tools/",
  ]);
});

test("every file directly in tools/ has a row in the tools/README.md table, and every row a file", () => {
  assert.deepEqual(readmeTableProblems(tools), []);
});
