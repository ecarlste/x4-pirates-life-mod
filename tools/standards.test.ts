// The mechanical rules for tools/ (tools/README.md's Rules section points here): caret ranges for
// devDependencies, no hand-read process arguments, every CLI's answer to an unknown option, only
// CLIs loose in tools/, and a tools/README.md table row for every file in tools/.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const tools = join(root, "tools");

// devDependencies entries whose range doesn't start with ^
const nonCaret = (pkg: { devDependencies?: Record<string, string> }): string[] =>
  Object.entries(pkg.devDependencies ?? {})
    .filter(([, range]) => !range.startsWith("^"))
    .map(([name, range]) => `${name}: ${range}`);

// Matches the global's property read, but not this file's own source
const ARGV = /\bprocess\s*\.\s*argv\b/;
const readsArgv = (source: string): boolean => ARGV.test(source);

// A CLI uses parseArgs (with the argv rule above, every CLI does), however it imports it
const isCli = (path: string, source: string): boolean => !path.endsWith(".test.ts") && /\bparseArgs\b/.test(source);

// What's wrong with a CLI's answer to --no-such-option; undefined when it exits 2 with Usage: on stderr
function unknownOptionProblem(cli: string): string | undefined {
  const result = spawnSync(process.execPath, [cli, "--no-such-option"], { encoding: "utf8", timeout: 30_000 });
  const problems = [];
  if (result.status !== 2) problems.push(`exits ${result.status ?? result.signal}, not 2`);
  if (!result.stderr.includes("Usage:")) problems.push("prints no Usage: line to stderr");
  return problems.length ? problems.join(", ") : undefined;
}

// This file checks tools/ as a whole, so it's the one test that sits loose in tools/
const SELF = "standards.test.ts";

// Files (not folders) directly in a tools/ folder, sorted
const looseFiles = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .sort();

// .ts files directly in a tools/ folder that aren't CLIs: a module or a test belongs in its tool's folder
function looseModules(dir: string): string[] {
  return looseFiles(dir)
    .filter((name) => name.endsWith(".ts") && name !== SELF)
    .filter((name) => !isCli(name, readFileSync(join(dir, name), "utf8")))
    .map((name) =>
      name.endsWith(".test.ts")
        ? `tools/${name}: a test loose in tools/; move it into its tool's folder`
        : `tools/${name}: a module loose in tools/; move it into its tool's folder`,
    );
}

// The files a tools/ folder's README.md table lists: each table row's first cell links its file
const README_ROW = /^\|\s*\[[^\]]*\]\(([^)]+)\)\s*\|/;
const readmeRows = (dir: string): string[] =>
  readFileSync(join(dir, "README.md"), "utf8")
    .split("\n")
    .flatMap((line) => line.match(README_ROW)?.[1] ?? []);

// Files directly in a tools/ folder with no README.md table row, then rows naming no such file
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

const tsFiles = (): string[] =>
  readdirSync(tools, { recursive: true, encoding: "utf8" })
    .filter((path) => path.endsWith(".ts") && !path.split("/").includes("node_modules"))
    .map((path) => `tools/${path}`)
    .sort();

const read = (path: string) => readFileSync(join(root, path), "utf8");

// A tools/ folder in a temp dir with these files in it (a name with a / makes its folder)
function plant(files: Record<string, string>): string {
  const dir = mkdtempSync(join(tmpdir(), "standards-"));
  for (const [name, content] of Object.entries(files)) {
    if (name.includes("/")) mkdirSync(join(dir, name, ".."), { recursive: true });
    writeFileSync(join(dir, name), content);
  }
  return dir;
}

const CLI = 'import { parseArgs } from "node:util";\nparseArgs({ options: {} });\n';

test("nonCaret finds a pinned or tilde range", () => {
  assert.deepEqual(nonCaret({ devDependencies: { a: "^1.0.0", b: "1.0.0", c: "~2.0.0" } }), ["b: 1.0.0", "c: ~2.0.0"]);
  assert.deepEqual(nonCaret({}), []);
});

test("every devDependency in package.json uses a ^ range", () => {
  const pkg = JSON.parse(read("package.json"));
  assert.deepEqual(nonCaret(pkg), [], "Use ^ ranges in package.json's devDependencies; package-lock.json pins.");
});

test("readsArgv finds the global's argv read, however it's spaced", () => {
  const argv = ["process", "argv"].join(".");
  assert.ok(readsArgv(`const [a] = ${argv}.slice(2);`));
  assert.ok(readsArgv(`if (${["process ", "argv"].join(".")}[1]) {}`));
  assert.ok(!readsArgv("parseArgs({ options: {} });"));
});

test("no .ts file under tools/ reads process arguments by hand", () => {
  const offenders = tsFiles().filter((path) => readsArgv(read(path)));
  assert.deepEqual(offenders, [], "Read arguments with parseArgs from node:util; use import.meta.main to tell a CLI run from an import.");
});

test("isCli takes non-test files that use parseArgs", () => {
  const source = 'import { parseArgs } from "node:util";';
  assert.ok(isCli("tools/a.ts", source));
  assert.ok(isCli("tools/a.ts", 'import * as util from "node:util";\nutil.parseArgs({});'));
  assert.ok(!isCli("tools/a.test.ts", source));
  assert.ok(!isCli("tools/a.ts", 'import { format } from "node:util";'));
});

test("unknownOptionProblem catches a CLI that lets parseArgs throw", () => {
  const dir = plant({
    "uncaught.ts": CLI,
    "caught.ts": 'import { parseArgs } from "node:util";\ntry { parseArgs({ options: {} }); } catch { console.error("Usage: x"); process.exit(2); }\n',
  });
  assert.equal(unknownOptionProblem(join(dir, "uncaught.ts")), "exits 1, not 2, prints no Usage: line to stderr");
  assert.equal(unknownOptionProblem(join(dir, "caught.ts")), undefined);
});

test("every CLI under tools/ exits 2 with a Usage: line on an unknown option", () => {
  const clis = tsFiles().filter((path) => isCli(path, read(path)));
  assert.ok(clis.length > 0, "found no CLIs");
  const problems = clis.flatMap((cli) => {
    const problem = unknownOptionProblem(join(root, cli));
    return problem ? [`${cli}: ${problem}`] : [];
  });
  assert.deepEqual(problems, [], "Catch the error parseArgs throws, print a usage line to stderr and exit 2, as tools/check-deps.ts does.");
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
  assert.deepEqual(looseModules(tools), [], "tools/README.md's Rules: tool.ts, with its modules and *.test.ts files in tool/.");
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
  assert.deepEqual(readmeTableProblems(tools), [], "Add a row for each script to tools/README.md's table, and take out a removed script's row.");
});
