import { test } from "node:test";
import assert from "node:assert/strict";
import { formatSummary, summarizeRun } from "./summary.ts";

// One capture_wing_breaks_full_shields run, trimmed from a real trace (#205, PR #207): lines as the
// runner keeps them, the order's and the pass's debug lines and the test's once-a-second trace
const WING_RUN = [
  "[General] 1.01 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 0, hull 100%, shields 100%, wingman 2000m away, knock-downs 0",
  "[Scripts] 3.02 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/LN (ZSX-457), led by Fortitude-class (PTD-300) with 1 wingmen (hold 75%, floor 35%, fear 0)",
  "[Scripts] 3.03 *** aicontext<order.apirateslife.capture,0x9d3f>: [apirateslife] capture order: X-wing T65B closes in on IMP TIE/LN: hull 100%, shields 100% (900, stop at 5616), distance 2000.75m",
  "[General] 8.83 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 7, hull 100%, shields 100%, wingman 481.875m away, knock-downs 0",
  "[Scripts] 9.11 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: starts at 390.438m, shields 100%, hull 100%",
  "[General] 9.85 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 8, hull 100%, shields 64.4444%, wingman 153.938m away, knock-downs 0",
  "[Scripts] 10.16 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: breaks off at 79.1406m, shields 11.1111%, hull 100%",
  "[General] 24.06 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 22, hull 100%, shields 24.0901%, wingman 443.062m away, knock-downs 1",
  "[Scripts] 24.06 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: turns back at 443.062m",
  "[Scripts] 24.06 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: starts at 443.062m, shields 24.0901%, hull 100%",
  "[Scripts] 30.56 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: breaks off at 75.9219m, shields 45.766%, hull 100%",
  "[Scripts] 38.06 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: starts at 438.75m, shields 70%, hull 100%",
  "[Scripts] 38.90 *** aicontext<order.apirateslife.capture,0x9d3f>: [apirateslife] capture order: X-wing T65B shields down, trims to 2 guns, hull 72.5%",
  "[General] 39.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 37, hull 72.5%, shields 0%, wingman 60m away, knock-downs 1",
  "[General] 40.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS capture_wing_breaks_full_shields: after 38 s: hull 72.5% (lowest 72.5%), shields 0%, 2 knock-downs, longest at full shields 8 s",
];

test("a capture run's gate time, lowest hull, knock-downs, longest full-shield stretch and passes", () => {
  assert.deepEqual(summarizeRun(WING_RUN), {
    result: "PASS",
    // From the operation's start (3.02) to the first line inside both bail gates: the order's
    // "shields down" with the hull under its 75% hold (38.90)
    gateSeconds: 35.88,
    gate: "reached",
    lowestHull: 72.5,
    // Shields from 20% or more to under 20%: 64% -> 11%, then 70% -> 0%
    knockDowns: 2,
    // Full (99% or more) from 1.01 until the 64% line at 9.85
    longestFullShieldsSeconds: 8.84,
    // A pass hits when the shields or the hull go under where they started, before the next pass
    // starts (bolts still in flight after the break-off count)
    passes: [
      // Shields 100% -> 11.1% by the break-off
      { startDistance: 390.438, shieldsBefore: 100, shieldsAfter: 11.1111, hullBefore: 100, hit: true, hullDrop: 0 },
      // Shields only regrew from 24.1%: no hit seen
      { startDistance: 443.062, shieldsBefore: 24.0901, shieldsAfter: 45.766, hullBefore: 100, hit: false, hullDrop: 0 },
      // Never broke off: the hit that took the shields down sent the order back to decide, at hull 72.5%
      { startDistance: 438.75, shieldsBefore: 70, shieldsAfter: undefined, hullBefore: 100, hit: true, hullDrop: 27.5 },
    ],
  });
});

test("the summary line rounds each figure and names a pass that never broke off", () => {
  assert.equal(
    formatSummary("capture_wing_breaks_full_shields-1", summarizeRun(WING_RUN)),
    "capture_wing_breaks_full_shields-1 PASS: gate 35.9 s, lowest hull 72.5%, 2 knock-downs, longest at full shields 8.8 s, " +
      "3 passes, 2 with a hit (start, shields before -> after, hit or miss, hull drop): " +
      "390 m 100 -> 11% hit, 443 m 24 -> 46% miss, 439 m 70% aborted hit hull -27.5%",
  );
});

test("a run whose operation never got inside the bail gates says so", () => {
  const summary = summarizeRun(WING_RUN.slice(0, 11));

  assert.equal(summary.result, "unfinished");
  assert.equal(summary.gate, "not reached");
  assert.equal(summary.lowestHull, 100);
  assert.match(formatSummary("x-1", summary), /^x-1 unfinished: gate not reached, lowest hull 100%, 1 knock-downs, /);
});

test("a target that starts under the hold reaches the gate once its shields are knocked down", () => {
  const summary = summarizeRun([
    "[Scripts] 102.69 *** Context:md.APiratesLife_Capture.Operation<inst:abab>: [apirateslife] capture: started on IMP TIE/LN (LID-179), led by Fortitude-class (AFE-849) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 102.87 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 2, hull 70%, shields 100%, wingman 1999m away, knock-downs 0",
    "[General] 109.12 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 8, hull 43.1429%, shields 0%, wingman 278.75m away, knock-downs 1",
  ]);

  assert.equal(summary.gateSeconds, 6.43);
});

test("the last run's order, still logging before this run's operation starts, isn't counted", () => {
  // From a -Repeat 3 run: run 2's finisher logs on after its result, in the same frame as run 3's
  // first trace line, so the runner puts those lines in run 3's file
  const summary = summarizeRun([
    "[General] 101.39 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 0, hull 100%, shields 100%, wingman 2000m away, knock-downs 0",
    "[Scripts] 101.39 *** aicontext<order.apirateslife.capture,0xa25c>: [apirateslife] capture order: X-wing T65B holds on event_object_hull_damaged: hull 74.6513%, shields 0% (0, stop at 5616)",
    "[Scripts] 101.40 *** aicontext<apirateslife.capture.pass,0xa25c>: [apirateslife] capture pass: starts at 262.812m, shields 3.68773%, hull 81.0927%",
    "[Scripts] 102.54 *** Context:md.APiratesLife_Capture.End<inst:a362>: [apirateslife] capture: ended on IMP TIE/LN (null): destroyed (fear left 0)",
    "[Scripts] 103.55 *** Context:md.APiratesLife_Capture.Operation<inst:a6d4>: [apirateslife] capture: started on IMP TIE/LN (DNF-130), led by Fortitude-class (JBJ-855) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 103.55 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 2, hull 100%, shields 100%, wingman 1981.25m away, knock-downs 0",
  ]);

  assert.equal(summary.lowestHull, 100);
  assert.equal(summary.knockDowns, 0);
  assert.deepEqual(summary.passes, []);
});

test("a run with no capture operation has no gate, no hull and no passes", () => {
  const summary = summarizeRun([
    "[General] 5.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] FAIL bail_raises_bailed: hull 54%, expected 100%;",
  ]);

  assert.equal(formatSummary("bail_raises_bailed-1", summary), "bail_raises_bailed-1 FAIL: no capture operation, no hull seen, 0 knock-downs, longest at full shields 0 s, 0 passes");
});
