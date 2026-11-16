// One game test run's trace (a file tools/run-game-tests.ps1 writes to tests/game/runs/) summed up.
// It reads the lines the capture order and the finisher's pass log at debugchance 100 and the
// tests' "[apirateslife-test] trace:" lines: every one with "hull N%" or "shields N%" (or the
// order's "shields down") is a sample of the target's state at the log's time stamp. The test's
// own result line is left out, as its detail can quote other figures (the lowest hull, an expected
// value). Before the run's operation starts, only the test's trace lines count: the last run's
// order can still log for a moment after its result, and the runner puts those lines in this run.

type Result = "PASS" | "FAIL" | "unfinished";

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
   * up to the next pass's start (or the run's end), so bolts still in flight after the break-off
   * count. Shields regrowing between two samples can hide a small hit. */
  hit: boolean;
  /** The hull the pass took off, in points of %: its start less the lowest hull before the next pass */
  hullDrop: number;
}

export interface RunSummary {
  result: Result;
  /** "reached": the target was inside both bail gates (the hull under the operation's hold, the
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
}

// The shields' bail gate, where the wing tests also count a knock-down
const SHIELDS_GATE = 20;
const FULL = 99;

const num = (s: string) => Number.parseFloat(s);
// Differences of two-decimal time stamps, without the float noise
const seconds = (from: number, to: number) => Math.round((to - from) * 100) / 100;

export function summarizeRun(lines: string[]): RunSummary {
  let result: Result = "unfinished";
  let start: number | undefined;
  let hold: number | undefined;
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
  let open: Pass | undefined;
  // The pass whose window is open, from its start to the next pass's start
  let current: Pass | undefined;

  for (const line of lines) {
    const time = /^\[[^\]]*\]\s+([\d.]+)\s/.exec(line);
    if (!time) continue;
    const t = num(time[1]);
    const outcome = /\[apirateslife-test\] (PASS|FAIL) /.exec(line);
    if (outcome) {
      result = outcome[1] as Result;
      continue;
    }
    const started = /\[apirateslife\] capture: started on .*\(hold ([\d.]+)%/.exec(line);
    if (started && start === undefined) {
      start = t;
      hold = num(started[1]);
    }
    const ours = start !== undefined || /\[apirateslife-test\] trace:/.test(line);
    if (!ours) continue;
    const passStart = /\[apirateslife\] capture pass: starts at ([\d.]+)m, shields ([\d.]+)%, hull ([\d.]+)%/.exec(line);
    if (passStart) {
      open = {
        startDistance: num(passStart[1]),
        shieldsBefore: num(passStart[2]),
        shieldsAfter: undefined,
        hullBefore: num(passStart[3]),
        hit: false,
        hullDrop: 0,
      };
      passes.push(open);
      current = open;
    }
    const breakOff = /\[apirateslife\] capture pass: breaks off at [\d.]+m, shields ([\d.]+)%/.exec(line);
    if (breakOff && open) {
      open.shieldsAfter = num(breakOff[1]);
      open = undefined;
    }

    const hull = /\bhull ([\d.]+)%/.exec(line);
    if (hull) {
      lastHull = num(hull[1]);
      lowestHull = lowestHull === undefined ? lastHull : Math.min(lowestHull, lastHull);
    }
    const shieldsLine = /\bshields (?:up )?([\d.]+)%/.exec(line);
    const shields = shieldsLine ? num(shieldsLine[1]) : /\bshields down\b/.test(line) ? 0 : undefined;
    if (shields !== undefined) lastShields = shields;
    if (current && !passStart) {
      if (shields !== undefined && shields < current.shieldsBefore) current.hit = true;
      if (hull && lastHull! < current.hullBefore) {
        current.hit = true;
        current.hullDrop = Math.max(current.hullDrop, Math.round((current.hullBefore - lastHull!) * 1e4) / 1e4);
      }
    }
    if (
      (hull || shields !== undefined) && start !== undefined && hold !== undefined && gateSeconds === undefined &&
      lastHull !== undefined && lastHull < hold && lastShields !== undefined && lastShields < SHIELDS_GATE
    ) {
      gateSeconds = seconds(start, t);
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
  if (fullSince !== undefined && lastShieldsTime !== undefined) longest = Math.max(longest, seconds(fullSince, lastShieldsTime));

  return {
    result,
    gate: start === undefined ? "no operation" : gateSeconds === undefined ? "not reached" : "reached",
    gateSeconds,
    lowestHull,
    knockDowns,
    longestFullShieldsSeconds: longest,
    passes,
  };
}

const round = (n: number, places = 0) => String(Math.round(n * 10 ** places) / 10 ** places);

/** One line: "<label> <result>: gate …, lowest hull …, … knock-downs, longest at full shields …, <n> passes …" */
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
  return (
    `${label} ${s.result}: ${gate}, ${hull}, ${s.knockDowns} knock-downs, ` +
    `longest at full shields ${round(s.longestFullShieldsSeconds, 1)} s, ${s.passes.length} passes${hits}${passList}`
  );
}
