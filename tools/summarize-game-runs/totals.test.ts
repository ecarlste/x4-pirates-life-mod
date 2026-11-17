import { test } from "node:test";
import assert from "node:assert/strict";
import type { Pass, RunSummary } from "./summary.ts";
import { formatTotals, totalRuns } from "./totals.ts";

const pass = (shieldsBefore: number, hit: boolean): Pass => ({
  startDistance: 400,
  shieldsBefore,
  shieldsAfter: undefined,
  hullBefore: 100,
  hit,
  hullDrop: 0,
});

const run = (over: Partial<RunSummary>): RunSummary => ({
  result: "PASS",
  gate: "reached",
  gateSeconds: 30,
  lowestHull: 70,
  knockDowns: 1,
  longestFullShieldsSeconds: 8,
  passes: [],
  gunSwaps: [],
  combatTrace: [],
  outcome: undefined,
  bailChecks: [],
  noBailChance: 1,
  inGatesSeconds: 0,
  ...over,
});

const bands = (a: number[], b: number[]) => [
  { band: "0-3 deg under 600 m", damage: a[0], fired: a[1], inBand: a[2] },
  { band: "over 20 deg 1400 m+", damage: b[0], fired: b[1], inBand: b[2] },
];

// Four runs of one test: one failed, one never reached the gates, one saw no hull at all
const BATCH = [
  run({
    gateSeconds: 30,
    lowestHull: 70,
    // Shields under 0.5% show as 0% on the run's line, so they count as down
    passes: [pass(100, true), pass(0.3, true), pass(40, false)],
    gunSwaps: ["0xb1 for 0xb2"],
    combatTrace: [{ wingman: "1 of 1", seconds: 60, shots: 30, overheats: 1, bands: bands([1, 2, 3], [0, 0, 57]) }],
  }),
  run({
    result: "FAIL",
    gateSeconds: 50,
    lowestHull: 54,
    passes: [pass(0, false), pass(0, true)],
    gunSwaps: ["0xa1 for 0xa2", "0xa2 for 0xa1"],
    combatTrace: [{ wingman: "1 of 1", seconds: 40, shots: 10, overheats: 0, bands: bands([2, 3, 4], [1, 1, 36]) }],
  }),
  run({ gate: "not reached", gateSeconds: undefined, lowestHull: 90, passes: [pass(100, false)] }),
  run({ result: "unfinished", gate: "no operation", gateSeconds: undefined, lowestHull: undefined }),
];

test("a batch's totals: runs, passes, finisher hits by shields, lowest hull, gate times, swaps and bands", () => {
  assert.deepEqual(totalRuns(BATCH), {
    runs: 4,
    passed: 2,
    finisherPasses: { total: 6, hit: 3, shieldsDown: { total: 3, hit: 2 }, shieldsUp: { total: 3, hit: 1 } },
    lowestHull: { runs: 3, min: 54, p50: 70 },
    gate: { reached: 2, times: { p50: 30, p90: 50 } },
    gunSwaps: { count: 3, runs: 2 },
    combatTrace: [
      { wingman: "1 of 1", runs: 2, seconds: 100, shots: 40, overheats: 1, bands: bands([3, 5, 7], [1, 1, 93]) },
    ],
    bail: { checks: 0, meanChecks: 0, meanInGatesSeconds: 0 },
    // No run reported an outcome
    byOutcome: {},
  });
});

test("percentiles are nearest-rank: p50 of four is the second, p90 of four the fourth", () => {
  const totals = totalRuns([10, 40, 20, 30].map((gateSeconds) => run({ gateSeconds })));

  assert.deepEqual(totals.gate, { reached: 4, times: { p50: 20, p90: 40 } });
});

test("the totals block: a line per figure, under the test's name", () => {
  assert.equal(
    formatTotals("capture_wing_holds_fire", totalRuns(BATCH)),
    [
      "capture_wing_holds_fire totals: 4 runs, 2 passed",
      "  finisher passes: 3 of 6 hit; at shields 0%: 2 of 3, shields up: 1 of 3",
      "  lowest hull (3 runs): min 54%, p50 70%",
      "  gate: reached in 2 of 4 runs, p50 30 s, p90 50 s",
      "  gun swaps: 3, in 2 of 4 runs",
      "  combat trace, wingman 1 of 1 (2 runs): 100 s, shots 40, overheats 1; seconds with damage/fired/in band: " +
        "0-3 deg under 600 m 3/5/7, over 20 deg 1400 m+ 1/1/93",
      "  bail checks: 0, mean 0 per run; in the gates: mean 0 s per run",
    ].join("\n"),
  );
});

test("a batch with no capture operation says what it didn't see", () => {
  const totals = totalRuns([run({ result: "FAIL", gate: "no operation", gateSeconds: undefined, lowestHull: undefined })]);

  assert.equal(
    formatTotals("bail_raises_bailed", totals),
    [
      "bail_raises_bailed totals: 1 runs, 0 passed",
      "  finisher passes: none",
      "  lowest hull: none seen",
      "  gate: reached in 0 of 1 runs",
      "  gun swaps: none",
      "  bail checks: 0, mean 0 per run; in the gates: mean 0 s per run",
    ].join("\n"),
  );
});

// Four runs of a test with a split verdict: two bailed, two timed out
const SPLIT = [
  run({ outcome: "met", bailChecks: [20, 50, 70], noBailChance: 0.12, inGatesSeconds: 25.5 }),
  run({ outcome: "met", bailChecks: [90], noBailChance: 0.1, inGatesSeconds: 4.5 }),
  run({ result: "FAIL", outcome: "missed", bailChecks: [20, 50], noBailChance: 0.4, inGatesSeconds: 273 }),
  run({ result: "FAIL", outcome: "missed", bailChecks: [], noBailChance: 1, inGatesSeconds: 25 }),
];

test("a split verdict's totals: bail checks and time in the gates by outcome, and the misses' odds of no bail", () => {
  const totals = totalRuns(SPLIT);

  assert.deepEqual(totals.bail, { checks: 6, meanChecks: 1.5, meanInGatesSeconds: 82 });
  assert.deepEqual(totals.byOutcome, {
    met: { runs: 2, meanChecks: 2, meanInGatesSeconds: 15 },
    missed: { runs: 2, meanChecks: 1, meanInGatesSeconds: 149, noBailChances: [0.4, 1] },
  });
  assert.equal(
    formatTotals("capture_wing_bails_phantom", totals).split("\n").slice(-3).join("\n"),
    [
      "  bail checks: 6, mean 1.5 per run; in the gates: mean 82 s per run",
      "  outcome met in 2 of 4 runs: mean 2 bail checks, 15 s in the gates",
      "  outcome missed in 2 of 4 runs: mean 1 bail checks, 149 s in the gates; P(no bail) each: 40%, 100%",
    ].join("\n"),
  );
});
