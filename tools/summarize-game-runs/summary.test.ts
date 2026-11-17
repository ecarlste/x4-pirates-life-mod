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
    gunSwaps: [],
    combatTrace: [],
    outcome: undefined,
    bailChecks: [],
    noBailChance: 1,
    // Inside both gates from 38.90 to the run's last sample, 39.00
    inGatesSeconds: 0.1,
    stops: [],
  });
});

test("the summary line rounds each figure and names a pass that never broke off", () => {
  assert.equal(
    formatSummary("capture_wing_breaks_full_shields-1", summarizeRun(WING_RUN)),
    "capture_wing_breaks_full_shields-1 PASS: gate 35.9 s, lowest hull 72.5%, 2 knock-downs, longest at full shields 8.8 s, " +
      "0 bail checks, P(no bail) 100%, 0.1 s in the gates, 3 passes, 2 with a hit (start, shields before -> after, hit or miss, hull drop): " +
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

test("probe lines tagged [DEBUG-*] aren't counted, bare or in a test's trace", () => {
  // The runner keeps probe lines in the trace for reading (#278); their figures can be any ship's
  const summary = summarizeRun([
    "[Scripts] 3.02 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/LN (ZSX-457), led by Fortitude-class (PTD-300) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 4.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 1, hull 90%, shields 100%, wingman 1500m away, knock-downs 0",
    "[Scripts] 5.00 *** Context:md.APiratesLife_Tests.Probe: [DEBUG-x] probe: hull 10%, shields 5%",
    "[General] 6.00 *** Context:md.APiratesLife_Tests.Probe: [apirateslife-test] [DEBUG-x] trace: hull 20%, shields 0%",
    "[General] 7.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 4, hull 85%, shields 100%, wingman 900m away, knock-downs 0",
  ]);

  assert.equal(summary.lowestHull, 85);
  assert.equal(summary.knockDowns, 0);
  assert.equal(summary.gate, "not reached");
});

test("a run with no capture operation has no gate, no hull and no passes", () => {
  const summary = summarizeRun([
    "[General] 5.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] FAIL bail_raises_bailed: hull 54%, expected 100%;",
  ]);

  assert.equal(formatSummary("bail_raises_bailed-1", summary), "bail_raises_bailed-1 FAIL: no capture operation, no hull seen, 0 knock-downs, longest at full shields 0 s, 0 bail checks, P(no bail) 100%, 0 s in the gates, 0 passes");
});

test("a pass's window closes once the finisher stops finishing, so the wing's later fire isn't counted", () => {
  // Trimmed from a capture_wing_holds_fire run at 1x (#224): the pass takes the hull under the 75%
  // hold, the order holds, and later fire on the regrown shields isn't the pass's
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/x1 (ABC-123), led by Fortitude-class (PTD-300) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[Scripts] 9.00 *** aicontext<apirateslife.capture.pass,0x9d3f>: [apirateslife] capture pass: starts at 410.5m, shields 0%, hull 80%",
    "[General] 10.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 77%, shields 0%, wingman 200m away",
    "[Scripts] 10.40 *** aicontext<order.apirateslife.capture,0x9d3f>: [apirateslife] capture order: X-wing T65B holds on event_object_hull_damaged: hull 73.5%, shields 0% (0, stop at 180)",
    "[General] 30.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 70.25%, shields 0%, wingman 300m away",
  ]);

  assert.deepEqual(summary.passes, [
    { startDistance: 410.5, shieldsBefore: 0, shieldsAfter: undefined, hullBefore: 80, hit: true, hullDrop: 6.5 },
  ]);
  assert.equal(summary.lowestHull, 70.25);
});

test("a run's gun swaps and combat trace lines, as logged", () => {
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/LN (ABC-123), led by Fortitude-class (PTD-300) with 2 wingmen (hold 75%, floor 35%, fear 0)",
    "[Scripts] 20.00 *** aicontext<order.apirateslife.capture,0x9d3f>: [apirateslife] capture order: X-wing T65B missed for 6s, swaps gun laser_a for laser_b, guns in group 2, hull 90%",
    "[General] 60.00 *** Context:md.APiratesLife_Tests.CombatTraceStop: [apirateslife-test] combat trace capture_wing_holds_fire, wingman 1 of 2: 58 s, shots 34, overheats 1; seconds with damage/fired/in band, by nose angle and distance: 0-3 deg under 600 m 1/2/3, over 20 deg 1400 m+ 0/0/7",
    "[General] 60.00 *** Context:md.APiratesLife_Tests.CombatTraceStop: [apirateslife-test] combat trace capture_wing_holds_fire, wingman 2 of 2: 58 s, shots 0, overheats 0; seconds with damage/fired/in band, by nose angle and distance: 0-3 deg under 600 m 0/0/0, over 20 deg 1400 m+ 4/5/58",
  ]);

  assert.deepEqual(summary.gunSwaps, ["laser_a for laser_b"]);
  assert.deepEqual(summary.combatTrace, [
    {
      wingman: "1 of 2", seconds: 58, shots: 34, overheats: 1,
      bands: [
        { band: "0-3 deg under 600 m", damage: 1, fired: 2, inBand: 3 },
        { band: "over 20 deg 1400 m+", damage: 0, fired: 0, inBand: 7 },
      ],
    },
    {
      wingman: "2 of 2", seconds: 58, shots: 0, overheats: 0,
      bands: [
        { band: "0-3 deg under 600 m", damage: 0, fired: 0, inBand: 0 },
        { band: "over 20 deg 1400 m+", damage: 4, fired: 5, inBand: 58 },
      ],
    },
  ]);
  // The swap line's hull is a sample like any other
  assert.equal(summary.lowestHull, 90);
});

test("a combat trace counts in a run with no capture operation, as in the turret tests on vanilla's attack", () => {
  const summary = summarizeRun([
    "[General] 60.00 *** Context:md.APiratesLife_Tests.CombatTraceStop: [apirateslife-test] combat trace turret_damage_landed_s, wingman 1 of 1: 58 s, shots 12, overheats 0; seconds with damage/fired/in band, by nose angle and distance: 0-3 deg under 600 m 1/2/3",
  ]);

  assert.equal(summary.gate, "no operation");
  assert.deepEqual(summary.combatTrace.map((t) => t.shots), [12]);
});

// A Phantom bail run (#272's shape, trimmed): the pressure tick's checks while inside the gates, a
// bail, the operation's end and the capture metrics line, whose own "outcome=" isn't the test's
const BAILED_RUN = [
  "[Scripts] 3.00 *** Context:md.APiratesLife_Capture.Operation<inst:1>: [apirateslife] capture: started on IMP TIE Phantom (PHA-001), led by X-wing T65B (XWG-001) with 1 wingmen (hold 75%, floor 35%, fear 0)",
  "[General] 10.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 70%, shields 50%",
  "[General] 20.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 70%, shields 10%",
  "[Scripts] 25.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE Phantom (PHA-001): chance 10 -> 20 (pressure 10)",
  "[General] 30.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 68%, shields 40%",
  "[General] 40.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 66%, shields 5%",
  "[Scripts] 45.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE Phantom (PHA-001): chance 10 -> 50 (pressure 40)",
  "[Scripts] 50.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE Phantom (PHA-001): chance 10 -> 70 (pressure 60)",
  "[Scripts] 50.00 *** Context:md.APiratesLife_Bail.Bailed: [apirateslife] bailed: 1 crew from IMP TIE Phantom (PHA-001) (attacker X-wing T65B (XWG-001)), pilot bailed: 1",
  "[Scripts] 55.50 *** Context:md.APiratesLife_Capture.End<inst:1>: [apirateslife] capture: ended on IMP TIE Phantom (PHA-001): bailed (fear left 0)",
  "[Scripts] 55.50 *** Context:md.APiratesLife_Metrics: [apirateslife] capture metrics: v=1 | mode=wing | outcome=destroyed | target=IMP TIE Phantom",
  "[General] 56.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] PASS capture_wing_bails_phantom outcome=met: bailed after 47 s (expected outcome=missed never)",
];

test("a run's bail checks, their odds of no bail, its seconds inside the gates and its outcome", () => {
  const summary = summarizeRun(BAILED_RUN);

  // Each check's chance after pressure, in %
  assert.deepEqual(summary.bailChecks, [20, 50, 70]);
  // 0.8 x 0.5 x 0.3
  assert.equal(summary.noBailChance, 0.12);
  // Inside both gates from 20 to 30 (shields back over 20%), then from 40 to the operation's end at 55.5
  assert.equal(summary.inGatesSeconds, 25.5);
  // From the result line only: not the metrics line's "outcome=destroyed" or the detail's
  assert.equal(summary.outcome, "met");
  assert.equal(
    formatSummary("capture_wing_bails_phantom-1", summary),
    "capture_wing_bails_phantom-1 PASS outcome=met: gate 17 s, lowest hull 66%, 2 knock-downs, longest at full shields 0 s, " +
      "3 bail checks (chance after pressure: 20%, 50%, 70%), P(no bail) 12%, 25.5 s in the gates, 0 passes",
  );
});

test("a timed-out run's checks count until its result, and the gates close at its last line", () => {
  const timedOut = [
    ...BAILED_RUN.slice(0, 7),
    "[General] 303.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 60%, shields 2%",
    "[General] 303.00 *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] FAIL capture_wing_bails_phantom outcome=missed: no bail in 300 s",
  ];
  const summary = summarizeRun(timedOut);

  assert.deepEqual(summary.bailChecks, [20, 50]);
  assert.equal(summary.noBailChance, 0.4);
  // 20 to 30, then 40 to the last sample at 303
  assert.equal(summary.inGatesSeconds, 273);
  assert.equal(summary.result, "FAIL");
  assert.equal(summary.outcome, "missed");
});

test("a run with no bail checks is certain not to bail, and no outcome when the test reports none", () => {
  const summary = summarizeRun(WING_RUN);

  assert.deepEqual(summary.bailChecks, []);
  assert.equal(summary.noBailChance, 1);
  assert.equal(summary.outcome, undefined);
  assert.match(formatSummary("x-1", summary), /, 0 bail checks, P\(no bail\) 100%, 0\.1 s in the gates, /);
});

test("the gates are the game's 75% hull, not the operation's hold", () => {
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:1>: [apirateslife] capture: started on IMP TIE/LN (TGT-001), led by X-wing T65B (XWG-001) with 1 wingmen (hold 60%, floor 35%, fear 0)",
    "[General] 10.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 70%, shields 0%",
    "[General] 20.00 *** Context:md.APiratesLife_Tests: [apirateslife-test] trace: hull 65%, shields 0%",
  ]);

  assert.equal(summary.gateSeconds, 8);
  assert.equal(summary.inGatesSeconds, 10);
});

test("only the operation's own target's checks count, until the operation ends", () => {
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:1>: [apirateslife] capture: started on IMP TIE/LN (TGT-001), led by X-wing T65B (XWG-001) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[Scripts] 5.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE/LN (TGT-001): chance 10 -> 30 (pressure 20)",
    "[Scripts] 6.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE/LN (OTH-002): chance 10 -> 10 (pressure 0)",
    "[Scripts] 7.00 *** Context:md.APiratesLife_Capture.End<inst:1>: [apirateslife] capture: ended on IMP TIE/LN (TGT-001): bailed (fear left 0)",
    "[Scripts] 8.00 *** Context:md.APiratesLife_Bail: [apirateslife] bail check: X-wing T65B (XWG-001) attacking IMP TIE/LN (TGT-001): chance 10 -> 10 (pressure 0)",
  ]);

  assert.deepEqual(summary.bailChecks, [30]);
});

// A capture_wing_holds_fire run at 1x, trimmed (release-1.00-date's trace): the finisher's hit takes
// the hull past the 75% hold, and the test's 1 s trace shows where it settles
const HOLD_RUN = [
  "[Scripts] 923.41 *** Context:md.APiratesLife_Capture.Operation<inst:e163>: [apirateslife] capture: started on IMP TIE/x1 (JHD-225), led by Fortitude-class (QFU-094) with 1 wingmen (hold 75%, floor 35%, fear 0)",
  "[Scripts] 933.65 *** Context:md.APiratesLife_Tests.CaptureWingHoldsFire_Watch<inst:e1e0>: [apirateslife-test] trace: hull 76.75%, shields 0%, wingman 62.1172m away at 206.406 m/s",
  "[Scripts] 933.81 *** aicontext<order.apirateslife.capture,0xe019>: [apirateslife] capture order: X-wing T65B holds on event_object_hull_damaged: hull 73.5%, shields 0% (0, stop at 5616)",
  "[Scripts] 933.81 *** aicontext<order.apirateslife.capture,0xe019>: [apirateslife] capture order: X-wing T65B holds on IMP TIE/x1: hull 73.5%, shields 0% (0, stop at 5616), distance 53.8984m",
  "[Scripts] 934.65 *** Context:md.APiratesLife_Tests.CaptureWingHoldsFire_Watch<inst:e1fd>: [apirateslife-test] trace: hull 70.25%, shields 0%, wingman 130.906m away at 266.188 m/s",
  "[Scripts] 936.85 *** Context:md.APiratesLife_Tests.CaptureWingHoldsFire_Watch<inst:e20c>: [apirateslife-test] trace: hull 70.25%, shields 0%, wingman 808.625m away at 343.562 m/s",
  "[Scripts] 937.85 *** Context:md.APiratesLife_Tests.CaptureWingHoldsFire_Watch<inst:e212>: [apirateslife-test] trace: hull 70.25%, shields 0.5%, wingman 1017m away at 256.062 m/s",
  "[Scripts] 938.85 *** Context:md.APiratesLife_Tests.CaptureWingHoldsFire_Watch<inst:e219>: [apirateslife-test] trace: hull 70.25%, shields 3%, wingman 1096m away at 181.156 m/s",
];

test("a stop in the break stage: the target's hull and shields at the stop and at the first sample 3 s or more later", () => {
  assert.deepEqual(summarizeRun(HOLD_RUN).stops, [
    // The hull was at 76.75%, over the 75% hold, before the hit that stopped the wing: the line.
    // 3 s after 933.81 is 936.81, so the 936.85 sample, not 937.85 where the shields regrow
    { stage: "line", seconds: 10.4, hullAt: 73.5, shieldsAt: 0, hullAfter: 70.25, shieldsAfter: 0 },
  ]);
});

test("a stop under the hold is in suppress; wingmen stopping within a second of it are the same stop", () => {
  // Three wingmen's hold handlers on one knock-down, then one 0.9 s later, still the same stop
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/LN (ABC-123), led by Fortitude-class (PTD-300) with 3 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 9.50 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 7, hull 70%, shields 40%, wingman 600m away, knock-downs 0",
    "[Scripts] 10.00 *** aicontext<order.apirateslife.capture,0x1>: [apirateslife] capture order: X-wing T65B holds on event_object_shield_damaged: hull 70%, shields 30% (270, stop at 270)",
    "[Scripts] 10.00 *** aicontext<order.apirateslife.capture,0x2>: [apirateslife] capture order: X-wing T65B holds on event_object_shield_damaged: hull 70%, shields 30% (270, stop at 270)",
    "[Scripts] 10.90 *** aicontext<order.apirateslife.capture,0x3>: [apirateslife] capture order: X-wing T65B holds on event_object_shield_damaged: hull 70%, shields 25% (225, stop at 270)",
    "[General] 12.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 10, hull 66%, shields 0%, wingman 500m away, knock-downs 1",
    "[General] 13.10 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 11, hull 65%, shields 2%, wingman 500m away, knock-downs 1",
  ]);

  assert.deepEqual(summary.stops, [
    { stage: "suppress", seconds: 8, hullAt: 70, shieldsAt: 30, hullAfter: 65, shieldsAfter: 2 },
  ]);
});

test("a stop with no sample 3 s later, as when the run ends first, has no figures after it", () => {
  const summary = summarizeRun(HOLD_RUN.slice(0, 5));

  assert.deepEqual(summary.stops.map((s) => [s.hullAfter, s.shieldsAfter]), [[undefined, undefined]]);
});

test("the summary line lists each stop: its stage, then hull and shields at it and 3 s later", () => {
  assert.match(
    formatSummary("capture_wing_holds_fire-1", summarizeRun(HOLD_RUN)),
    /, 0 passes, 1 stops \(stage at, hull\/shields at the stop -> 3 s later\): line 10\.4 s 73\.5\/0 -> 70\.3\/0%$/,
  );
  assert.match(formatSummary("x-1", summarizeRun(HOLD_RUN.slice(0, 5))), /: line 10\.4 s 73\.5\/0 -> no sample$/);
});

test("a stop's stage goes by the hull before the stop's frame: a sample in the same frame can already show the hit", () => {
  // capture_wing_holds_fire_three_wingmen at 1x: the test's trace logs the hit's 73.5% just before the hold handler does
  const summary = summarizeRun([
    "[Scripts] 600.00 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE/x1 (ABC-123), led by Fortitude-class (PTD-300) with 3 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 628.58 *** Context:md.APiratesLife_Tests.CheckWingHold: [apirateslife-test] trace: hull 76.75%, shields 0%, wingman 1589m away at 297.438 m/s",
    "[General] 629.58 *** Context:md.APiratesLife_Tests.CheckWingHold: [apirateslife-test] trace: hull 73.5%, shields 0%, wingman 1575.25m away at 71.4531 m/s",
    "[Scripts] 629.58 *** aicontext<order.apirateslife.capture,0x1>: [apirateslife] capture order: X-wing T65B holds on event_object_hull_damaged: hull 73.5%, shields 0% (0, stop at 1746.6)",
  ]);

  assert.deepEqual(summary.stops.map((s) => s.stage), ["line"]);
});

test("a stop with the hull still at or over the hold is the wing's burst stop, apart from the finisher's at the hold line", () => {
  // A TIE Phantom's big shields: the wing stops with 1.5 s of its fire left above the line
  const summary = summarizeRun([
    "[Scripts] 2.00 *** Context:md.APiratesLife_Capture.Operation<inst:9e3b>: [apirateslife] capture: started on IMP TIE Phantom (ABC-123), led by Fortitude-class (PTD-300) with 1 wingmen (hold 75%, floor 35%, fear 0)",
    "[General] 9.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 7, hull 100%, shields 60%, wingman 1500m away, knock-downs 0",
    "[Scripts] 9.50 *** aicontext<order.apirateslife.capture,0x1>: [apirateslife] capture order: X-wing T65B holds on event_object_shield_damaged: hull 100%, shields 40% (2240, stop at 5616)",
    "[General] 13.00 *** Context:md.APiratesLife_Tests.CheckWingCycle: [apirateslife-test] trace: t 11, hull 100%, shields 20%, wingman 1200m away, knock-downs 0",
  ]);

  assert.deepEqual(summary.stops, [{ stage: "burst", seconds: 7.5, hullAt: 100, shieldsAt: 40, hullAfter: 100, shieldsAfter: 20 }]);
});
