import { test } from "node:test";
import assert from "node:assert/strict";
import { planChunks, type Estimates } from "./plan.ts";

// The runner's estimates as -HoldEstimateOnly prints them: a 5-minute budget, 55 s of game start
const estimates = (...tests: [string, number][]): Estimates => ({
  budget: 300,
  gameStart: 55,
  tests: tests.map(([name, seconds]) => ({ name, seconds })),
});

test("a test's runs go in chunks that each fit the hold budget, the last one short", () => {
  // 55 s + 2 x 120 s = 295 s fits; a third run would be 415 s
  const chunks = planChunks(estimates(["capture_wing_knocks_shields_again", 120]), 5, "base");

  assert.deepEqual(
    chunks.map((c) => [c.test, c.runs, c.firstRun, c.hold]),
    [
      ["capture_wing_knocks_shields_again", 2, 1, 295],
      ["capture_wing_knocks_shields_again", 2, 3, 295],
      ["capture_wing_knocks_shields_again", 1, 5, 175],
    ],
  );
});

test("the first chunk clears the batch's traces and every later one appends, across tests", () => {
  const chunks = planChunks(estimates(["fight", 120], ["travel", 10]), 3, "proof-1");

  assert.deepEqual(
    chunks.map((c) => c.args.join(" ")),
    [
      "-Test fight -Repeat 2 -RunsLabel proof-1",
      "-Test fight -Repeat 1 -RunsLabel proof-1 -RunsAppend",
      "-Test travel -Repeat 3 -RunsLabel proof-1 -RunsAppend",
    ],
  );
});

test("a test that reports from its own actions takes no time, so all its runs go in one chunk", () => {
  const chunks = planChunks(estimates(["instant", 0]), 40, "base");

  assert.deepEqual(chunks.map((c) => [c.runs, c.hold, c.long]), [[40, 55, false]]);
});

test("a test whose single run is over the budget still runs, one run per chunk, called out as a long hold", () => {
  // A 300 s timeout (or no timeout cue, which the runner counts as the whole budget): 355 s a run
  const chunks = planChunks(estimates(["capture_wing_bails_phantom", 300], ["fight", 120]), 2, "base");

  assert.deepEqual(
    chunks.map((c) => [c.test, c.runs, c.hold, c.long]),
    [
      ["capture_wing_bails_phantom", 1, 355, true],
      ["capture_wing_bails_phantom", 1, 355, true],
      ["fight", 2, 295, false],
    ],
  );
});

test("a run that exactly fills the budget is not a long hold", () => {
  const chunks = planChunks(estimates(["fill", 245]), 1, "base");

  assert.deepEqual(chunks.map((c) => [c.hold, c.long]), [[300, false]]);
});

test("timeouts under SETA come in fractions of a second and still pack to the budget", () => {
  // 49 s / 6 a run: 30 runs is 55 s + 245 s exactly
  const chunks = planChunks(estimates(["travel", 49 / 6]), 31, "base");

  assert.deepEqual(chunks.map((c) => c.runs), [30, 1]);
});
