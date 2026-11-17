// One game test run's trace (a file tools/run-game-tests.ps1 writes to tests/game/runs/) summed up.
// It reads the lines the capture order and the finisher's pass log at debugchance 100 and the
// tests' "[apirateslife-test] trace:" lines: every one with "hull N%" or "shields N%" (or the
// order's "shields down") is a sample of the target's state at the log's time stamp. The test's
// own result line is left out, as its detail can quote other figures (the lowest hull, an expected
// value). Before the run's operation starts, only the test's trace lines count: the last run's
// order can still log for a moment after its result, and the runner puts those lines in this run.
// Lines with a "[DEBUG-" probe tag never count, bare or in a test's trace line.
// The result line gives the run's result and, for a test that reports one, its outcome; no other
// line's "outcome=" counts (the capture metrics line logs one too).

type Result = "PASS" | "FAIL" | "unfinished";
/** A split verdict, as a test that reports one logs it after its name */
export type Outcome = "met" | "missed";

export interface Pass {
  /** How far from the target the pass started, in m */
  startDistance: number;
  /** The target's shields when the pass started and when it broke off, in %; no break-off line
   * (the order aborted the pass, as on the hit that takes the shields down) leaves it undefined */
  shieldsBefore: number;
  shieldsAfter: number | undefined;
  /** The target's hull when the pass started, in % */
  hullBefore: number;
  /** Whether damage landed: the shields or the hull went under where they started, seen on any line
   * from the pass's start until the next pass starts or the finisher stops finishing (the order's
   * "fires on" or "holds on", or the operation's end), so bolts still in flight after the break-off
   * count. Shields regrowing between two samples can hide a small hit. */
  hit: boolean;
  /** The hull the pass took off, in points of %: its start less the lowest hull before the next pass */
  hullDrop: number;
}

/** One of the combat trace's nine bands for a wingman: the seconds damage landed, it fired, and all
 * its seconds there */
export interface Band {
  band: string;
  damage: number;
  fired: number;
  inBand: number;
}

/** A test's combat trace line for one wingman ("combat trace <test>, wingman N of M: …") */
export interface WingmanTrace {
  /** "N of M", as logged */
  wingman: string;
  seconds: number;
  shots: number;
  overheats: number;
  bands: Band[];
}

export interface RunSummary {
  result: Result;
  /** The split verdict from the result line's " outcome=met|missed", for a test that reports one */
  outcome: Outcome | undefined;
  /** "reached": the target was inside both bail gates (the hull under 75%, the
   * shields under 20%, each as last seen) gateSeconds after the operation started */
  gate: "reached" | "not reached" | "no operation";
  gateSeconds: number | undefined;
  lowestHull: number | undefined;
  /** Shields from 20% or more to under 20%, as the wing tests count them */
  knockDowns: number;
  /** The longest stretch with the shields at 99% or more, from the first full sample to the next
   * one that isn't (or the run's last sample) */
  longestFullShieldsSeconds: number;
  passes: Pass[];
  /** The capture order's gun swaps, each as logged: "<old gun> for <next gun>" */
  gunSwaps: string[];
  combatTrace: WingmanTrace[];
  /** The bail hook's checks on the operation's target from its start to its end, each its chance
   * after pressure, in % */
  bailChecks: number[];
  /** The odds no check bailed: each check's 1 - chance, multiplied */
  noBailChance: number;
  /** All the time inside both bail gates, as the samples show it, until the operation ends (or the
   * run's last line) */
  inGatesSeconds: number;
}

// The shields' bail gate, where the wing tests also count a knock-down
const SHIELDS_GATE = 20;
// The hull's bail gate: the game's, fixed whatever the operation's hold (InGates, md/apirateslife_capture.xml)
const HULL_GATE = 75;
const FULL = 99;

const num = (s: string) => Number.parseFloat(s);
// Differences of two-decimal time stamps, without the float noise
const seconds = (from: number, to: number) => Math.round((to - from) * 100) / 100;

export function summarizeRun(lines: string[]): RunSummary {
  let result: Result = "unfinished";
  let outcome: Outcome | undefined;
  let target: string | undefined;
  const bailChecks: number[] = [];
  let inGatesSince: number | undefined;
  let inGatesSeconds = 0;
  let ended = false;
  let lastTime: number | undefined;
  let start: number | undefined;
  let gateSeconds: number | undefined;
  let lowestHull: number | undefined;
  let lastHull: number | undefined;
  let lastShields: number | undefined;
  let knockDowns = 0;
  let shieldsUp = true;
  let fullSince: number | undefined;
  let longest = 0;
  let lastShieldsTime: number | undefined;
  const passes: Pass[] = [];
  const gunSwaps: string[] = [];
  const combatTrace: WingmanTrace[] = [];
  // The pass still waiting for its break-off line
  let awaitingBreakOff: Pass | undefined;
  // The pass that damage now counts for, from its start until the next pass starts or the
  // finisher stops finishing
  let counting: Pass | undefined;

  const leaveGates = (t: number) => {
    if (inGatesSince !== undefined) inGatesSeconds += seconds(inGatesSince, t);
    inGatesSince = undefined;
  };

  for (const line of lines) {
    // Probe lines are in the trace for reading, not for the summary: their figures can be any ship's
    if (line.includes("[DEBUG-")) continue;
    const time = /^\[[^\]]*\]\s+([\d.]+)\s/.exec(line);
    if (!time) continue;
    const t = num(time[1]);
    const resultLine = /\[apirateslife-test\] (PASS|FAIL) [^:]*?(?: outcome=(met|missed))?:/.exec(line);
    if (resultLine) {
      result = resultLine[1] as Result;
      outcome = resultLine[2] as Outcome | undefined;
      continue;
    }
    const started = /\[apirateslife\] capture: started on .* \(([^()]*)\), led by /.exec(line);
    if (started && start === undefined) {
      start = t;
      target = started[1];
    }
    // The test's own summary, logged before its result: it counts with or without an operation
    // (the turret tests trace vanilla's attack)
    const trace = /\[apirateslife-test\] combat trace .*, wingman (\d+ of \d+): ([\d.]+) s, shots (\d+), overheats (\d+); [^:]*: (.*)$/.exec(line);
    if (trace) {
      combatTrace.push({
        wingman: trace[1],
        seconds: num(trace[2]),
        shots: num(trace[3]),
        overheats: num(trace[4]),
        bands: trace[5].split(", ").flatMap((b) => {
          const m = /^(.*) (\d+)\/(\d+)\/(\d+)$/.exec(b);
          return m ? [{ band: m[1], damage: num(m[2]), fired: num(m[3]), inBand: num(m[4]) }] : [];
        }),
      });
      continue;
    }
    const ours = start !== undefined || /\[apirateslife-test\] trace:/.test(line);
    if (!ours) continue;
    if (start !== undefined) lastTime = t;
    // The hook logs every check, on any target, and its operation's target can still be checked after the end
    const check = /\[apirateslife\] bail check: .* attacking .* \(([^()]*)\): chance [\d.]+ -> ([\d.]+) \(pressure /.exec(line);
    if (check && start !== undefined && !ended && check[1] === target) bailChecks.push(num(check[2]));
    const swap = /\[apirateslife\] capture order: .*, swaps gun (.*), guns in group /.exec(line);
    if (swap) gunSwaps.push(swap[1]);
    const passStart = /\[apirateslife\] capture pass: starts at ([\d.]+)m, shields ([\d.]+)%, hull ([\d.]+)%/.exec(line);
    if (passStart) {
      awaitingBreakOff = {
        startDistance: num(passStart[1]),
        shieldsBefore: num(passStart[2]),
        shieldsAfter: undefined,
        hullBefore: num(passStart[3]),
        hit: false,
        hullDrop: 0,
      };
      passes.push(awaitingBreakOff);
      counting = awaitingBreakOff;
    }
    const breakOff = /\[apirateslife\] capture pass: breaks off at [\d.]+m, shields ([\d.]+)%/.exec(line);
    if (breakOff && awaitingBreakOff) {
      awaitingBreakOff.shieldsAfter = num(breakOff[1]);
      awaitingBreakOff = undefined;
    }

    const hull = /\bhull ([\d.]+)%/.exec(line);
    if (hull) {
      lastHull = num(hull[1]);
      lowestHull = lowestHull === undefined ? lastHull : Math.min(lowestHull, lastHull);
    }
    const shieldsLine = /\bshields (?:up )?([\d.]+)%/.exec(line);
    const shields = shieldsLine ? num(shieldsLine[1]) : /\bshields down\b/.test(line) ? 0 : undefined;
    if (shields !== undefined) lastShields = shields;
    if (counting && !passStart) {
      if (shields !== undefined && shields < counting.shieldsBefore) counting.hit = true;
      const h = hull ? num(hull[1]) : undefined;
      if (h !== undefined && h < counting.hullBefore) {
        counting.hit = true;
        // Rounded like the logged figures, without the float noise of the difference
        counting.hullDrop = Math.max(counting.hullDrop, Math.round((counting.hullBefore - h) * 1e4) / 1e4);
      }
      // The finisher stops finishing: the whole wing fires, or it holds (as on the hit that takes
      // the hull past the line), or the operation ends. This line's own figures still count.
      if (/\[apirateslife\] capture order: .* (?:fires|holds) on |\[apirateslife\] capture: ended /.test(line)) counting = undefined;
    }
    if ((hull || shields !== undefined) && start !== undefined && !ended) {
      const inGates = lastHull !== undefined && lastHull < HULL_GATE && lastShields !== undefined && lastShields < SHIELDS_GATE;
      if (inGates) {
        gateSeconds ??= seconds(start, t);
        inGatesSince ??= t;
      } else leaveGates(t);
    }
    if (start !== undefined && !ended && /\[apirateslife\] capture: ended /.test(line)) {
      ended = true;
      leaveGates(t);
    }
    if (shields !== undefined) {
      const s = shields;
      lastShieldsTime = t;
      if (shieldsUp && s < SHIELDS_GATE) {
        knockDowns++;
        shieldsUp = false;
      } else if (!shieldsUp && s >= SHIELDS_GATE) {
        shieldsUp = true;
      }
      if (s >= FULL) {
        fullSince ??= t;
      } else if (fullSince !== undefined) {
        longest = Math.max(longest, seconds(fullSince, t));
        fullSince = undefined;
      }
    }
  }
  if (lastTime !== undefined) leaveGates(lastTime);
  if (fullSince !== undefined && lastShieldsTime !== undefined) longest = Math.max(longest, seconds(fullSince, lastShieldsTime));

  return {
    result,
    outcome,
    gate: start === undefined ? "no operation" : gateSeconds === undefined ? "not reached" : "reached",
    gateSeconds,
    lowestHull,
    knockDowns,
    longestFullShieldsSeconds: longest,
    passes,
    gunSwaps,
    combatTrace,
    bailChecks,
    noBailChance: noBail(bailChecks),
    inGatesSeconds: Math.round(inGatesSeconds * 100) / 100,
  };
}

/** The odds that none of these checks (chances in %, clamped to 0-100) bailed */
const noBail = (chances: number[]) =>
  Math.round(chances.reduce((p, c) => p * (1 - Math.min(100, Math.max(0, c)) / 100), 1) * 1e6) / 1e6;

const round = (n: number, places = 0) => String(Math.round(n * 10 ** places) / 10 ** places);

/** One line: "<label> <result>[ outcome=…]: gate …, lowest hull …, … knock-downs, longest at full shields …,
 * <n> bail checks …, P(no bail) …, … s in the gates, <n> passes …" */
export function formatSummary(label: string, s: RunSummary): string {
  const gate = s.gate === "reached" ? `gate ${round(s.gateSeconds!, 1)} s` : s.gate === "not reached" ? "gate not reached" : "no capture operation";
  const hull = s.lowestHull === undefined ? "no hull seen" : `lowest hull ${round(s.lowestHull, 1)}%`;
  const passes = s.passes.map((p) => {
    const shields =
      p.shieldsAfter === undefined
        ? `${round(p.startDistance)} m ${round(p.shieldsBefore)}% aborted`
        : `${round(p.startDistance)} m ${round(p.shieldsBefore)} -> ${round(p.shieldsAfter)}%`;
    return `${shields} ${p.hit ? "hit" : "miss"}${p.hullDrop > 0 ? ` hull -${round(p.hullDrop, 1)}%` : ""}`;
  });
  const hits = s.passes.length ? `, ${s.passes.filter((p) => p.hit).length} with a hit` : "";
  const passList = passes.length ? ` (start, shields before -> after, hit or miss, hull drop): ${passes.join(", ")}` : "";
  const outcome = s.outcome ? ` outcome=${s.outcome}` : "";
  const checks = s.bailChecks.length ? ` (chance after pressure: ${s.bailChecks.map((c) => `${round(c, 1)}%`).join(", ")})` : "";
  return (
    `${label} ${s.result}${outcome}: ${gate}, ${hull}, ${s.knockDowns} knock-downs, ` +
    `longest at full shields ${round(s.longestFullShieldsSeconds, 1)} s, ` +
    `${s.bailChecks.length} bail checks${checks}, P(no bail) ${round(s.noBailChance * 100, 1)}%, ${round(s.inGatesSeconds, 1)} s in the gates, ` +
    `${s.passes.length} passes${hits}${passList}`
  );
}
