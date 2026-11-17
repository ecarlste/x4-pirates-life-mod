// Runs a long batch of game tests, a proof of a rate (docs/testing.md, Rates, not single runs), as
// several make game-test calls that each fit the hold budget (Keep each hold short), each rejoining
// the back of the game lock's line, with one trace set: the first call clears the label's traces
// and the rest add to them (-RunsAppend). The chunks are sized from the runner's own worst-case
// estimates (run-game-tests.ps1 -HoldEstimateOnly, tools/game-proof/plan.ts). Prints a line per
// chunk as it finishes and stops on a failed run (a missed outcome isn't one) unless --keep-going.
// make game-proof runs it, handing it the runner command (GAME_TEST_RUNNER); MAKE overrides the make
// it calls (the tests use a fake).
//
//   node tools/game-proof.ts --test <name>[,<name>...] --runs <n> --label <batch> [--keep-going]
import { spawn, spawnSync } from "node:child_process";
import { parseArgs } from "node:util";
import { planChunks, type Chunk, type Estimates } from "./game-proof/plan.ts";
import { formatSeconds, tallyChunk } from "./game-proof/tally.ts";

const usage = "Usage: node tools/game-proof.ts --test <name>[,<name>...] --runs <n> --label <batch> [--keep-going]";

let tests: string;
let runs: number;
let label: string;
let keepGoing: boolean;
try {
  const { values } = parseArgs({
    options: {
      test: { type: "string" },
      runs: { type: "string" },
      label: { type: "string" },
      "keep-going": { type: "boolean", default: false },
    },
  });
  if (!values.test || !/^\w+(,\w+)*$/.test(values.test)) throw new Error("--test needs test names, comma-separated");
  if (!values.runs || !/^[1-9]\d*$/.test(values.runs)) throw new Error("--runs needs a number of runs, 1 or more");
  // The runner's -RunsLabel rule: a folder name
  if (!values.label || !/^[A-Za-z0-9._-]+$/.test(values.label) || /^\.+$/.test(values.label)) {
    throw new Error("--label needs a folder name: letters, digits, '.', '_' and '-'");
  }
  tests = values.test;
  runs = Number(values.runs);
  label = values.label;
  keepGoing = values["keep-going"];
} catch (e) {
  console.error(`${(e as Error).message}\n${usage}`);
  process.exit(2);
}

const runner = process.env.GAME_TEST_RUNNER;
if (!runner) {
  console.error("GAME_TEST_RUNNER isn't set: run it as make game-proof, which sets it");
  process.exit(2);
}
const make = process.env.MAKE || "make";
const say = (line: string) => console.log(`game-proof: ${line}`);

// The runner's estimates for the tests; it fails on an unknown name, saying so
const estimate = spawnSync(`${runner} -HoldEstimateOnly -Test ${tests}`, { shell: true, encoding: "utf8" });
if (estimate.status !== 0) {
  process.stderr.write(estimate.stderr + estimate.stdout);
  console.error("game-proof: the runner couldn't estimate the tests' holds, so nothing ran");
  process.exit(1);
}
const json = estimate.stdout.split(/\r?\n/).find((l) => l.trimStart().startsWith("{"));
const estimates = JSON.parse(json ?? "null") as Estimates;

const chunks = planChunks(estimates, runs, label);
say(`${runs} runs each of ${estimates.tests.map((t) => t.name).join(", ")} as batch ${label}, in ${chunks.length} chunks within the ${estimates.budget / 60}-minute hold budget`);
for (const t of estimates.tests) {
  const one = estimates.gameStart + t.seconds;
  if (one > estimates.budget) {
    say(`${t.name}: one run could hold the game for up to ${formatSeconds(one)}, over the budget, so it runs one run per chunk`);
  }
}

// One make game-test call, its output passed through as it comes, and kept for the tally
function runChunk(chunk: Chunk): Promise<{ status: number; output: string }> {
  return new Promise((resolve) => {
    const child = spawn(make, ["--no-print-directory", "game-test", `RUNNER_ARGS=${chunk.args.join(" ")}`], {
      stdio: ["inherit", "pipe", "pipe"],
    });
    let output = "";
    child.stdout.on("data", (d: Buffer) => {
      output += d;
      process.stdout.write(d);
    });
    child.stderr.on("data", (d: Buffer) => {
      output += d;
      process.stderr.write(d);
    });
    child.on("close", (code) => resolve({ status: code ?? 1, output }));
  });
}

let failedChunks = 0;
for (const [i, chunk] of chunks.entries()) {
  const started = Date.now();
  const { status, output } = await runChunk(chunk);
  const t = tallyChunk(output, chunk.test);
  const last = chunk.firstRun + chunk.runs - 1;
  const which = chunk.runs === 1 ? `run ${last}` : `runs ${chunk.firstRun}-${last}`;
  const long = chunk.long ? `, a long hold of up to ${formatSeconds(chunk.hold)}` : "";
  say(
    `chunk ${i + 1} of ${chunks.length}: ${chunk.test} ${which} of ${runs}: ${status === 0 ? "" : "FAILED, "}` +
      `passed ${t.passed}, failed ${t.failed}; outcomes met ${t.met}, missed ${t.missed} (${formatSeconds((Date.now() - started) / 1000)}${long})`,
  );
  if (status !== 0) {
    failedChunks++;
    if (!keepGoing) {
      say(`stopped: chunk ${i + 1} failed (not just a missed outcome). Fix it and start again, or pass KEEP_GOING=1 to run on past failures`);
      break;
    }
  }
}
say(`totals: node tools/summarize-game-runs.ts --totals tests/game/runs/${label}`);
if (failedChunks) process.exitCode = 1;
