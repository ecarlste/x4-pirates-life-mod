// Sums up game test runs: one line per run trace (tools/summarize-game-runs/summary.ts), from the
// files tools/run-game-tests.ps1 leaves in tests/game/runs/ (<test>-<n>.log). Takes trace files or
// folders of them, tests/game/runs/ by default; a folder's traces print by test name, then run number.
// --totals then adds a block per test summed across its runs (tools/summarize-game-runs/totals.ts).
// Traces from more than one folder (a labelled batch each, -RunsLabel) are named, and totalled, by
// folder: "<folder>/<test>-<n>".
//
//   node tools/summarize-game-runs.ts [--totals] [<file or folder>...]
import { readdirSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { formatSummary, summarizeRun, type RunSummary } from "./summarize-game-runs/summary.ts";
import { formatTotals, totalRuns } from "./summarize-game-runs/totals.ts";

let paths: string[];
let totals: boolean;
try {
  const args = parseArgs({ options: { totals: { type: "boolean", default: false } }, allowPositionals: true });
  paths = args.positionals;
  totals = args.values.totals;
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/summarize-game-runs.ts [--totals] [<file or folder>...]`);
  process.exit(2);
}
if (paths.length === 0) paths = [join(dirname(dirname(fileURLToPath(import.meta.url))), "tests/game/runs")];

// "<test>-<n>.log" sorts by test, then n as a number, so run 10 comes after run 9
const key = (file: string) => {
  const m = /^(.*)-(\d+)\.log$/.exec(file);
  return m ? { name: m[1], n: Number(m[2]) } : { name: file, n: 0 };
};
const byRun = (a: string, b: string) => {
  const ka = key(a);
  const kb = key(b);
  return ka.name < kb.name ? -1 : ka.name > kb.name ? 1 : ka.n - kb.n;
};

const files: string[] = [];
for (const path of paths) {
  if (!statSync(path).isDirectory()) {
    files.push(path);
    continue;
  }
  const traces = readdirSync(path).filter((f) => f.endsWith(".log")).sort(byRun);
  if (traces.length === 0) {
    console.error(`No run traces (*.log) in ${path}. make game-test leaves them in tests/game/runs/.`);
    process.exit(1);
  }
  files.push(...traces.map((f) => join(path, f)));
}

// Named by folder only when the traces come from more than one
const byFolder = new Set(files.map((f) => resolve(dirname(f)))).size > 1;
const label = (file: string) => (byFolder ? `${basename(dirname(resolve(file)))}/` : "") + basename(file, ".log");

// Each test's runs, by "<folder>/<test>" or "<test>", in the order first seen
const tests = new Map<string, RunSummary[]>();
for (const file of files) {
  const summary = summarizeRun(readFileSync(file, "utf8").split(/\r?\n/));
  console.log(formatSummary(label(file), summary));
  const test = label(file).replace(/-\d+$/, "");
  tests.set(test, [...(tests.get(test) ?? []), summary]);
}
if (totals) {
  for (const [test, runs] of tests) console.log(`\n${formatTotals(test, totalRuns(runs))}`);
}
