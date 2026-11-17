// A batch of one test's runs summed up (summarize-game-runs --totals): the figures each run's
// summary (summary.ts) already holds, added or ranked across the runs. It reads no new log lines.
/** One stage's stops: all of them, and those with a sample 3 s later, which the rest are over */
export interface StageStops {
  total: number;
  withSample: number;
  /** How far the hull and the shields fell from the stop to 3 s later, in points of %; shields
   * that regrew count as 0 */
  hullDrop: { p50: number; max: number } | undefined;
  shieldsDrop: { p50: number; max: number } | undefined;
  hullAfterMin: number | undefined;
}

import { AFTER_STOP_SECONDS, STAGES, type Outcome, type RunSummary, type Stage, type Stop, type WingmanTrace } from "./summary.ts";

/** Bail checks per run and seconds inside the bail gates per run, as means */
interface BailMeans {
  runs: number;
  meanChecks: number;
  meanInGatesSeconds: number;
}

interface HitCount {
  total: number;
  hit: number;
}

export interface Totals {
  runs: number;
  passed: number;
  /** The finisher's passes, and those split by the target's shields at the pass's start: down
   * (under 0.5%, which a run's line shows as 0%) or up */
  finisherPasses: HitCount & { shieldsDown: HitCount; shieldsUp: HitCount };
  /** Over the runs that saw a hull */
  lowestHull: { runs: number; min: number; p50: number } | undefined;
  /** The runs that reached the gates, and their times; no times when none did */
  gate: { reached: number; times: { p50: number; p90: number } | undefined };
  /** The order's gun swaps, and the runs with one. Not by gun: the order logs each gun's
   * component ID, which differs from run to run */
  gunSwaps: { count: number; runs: number };
  /** Each wingman's combat trace lines ("N of M") summed, with the runs that logged one */
  combatTrace: (WingmanTrace & { runs: number })[];
  /** The bail checks across the runs, and the means per run */
  bail: BailMeans & { checks: number };
  /** The runs by their split verdict, for a test that reports one; each miss's odds that none of
   * its checks bailed, lowest first, show whether it lost its rolls or had too few */
  byOutcome: { met?: BailMeans; missed?: BailMeans & { noBailChances: number[] } };
  /** The wing's stops by stage, over every run */
  stops: Record<Stage, StageStops>;
}

// Shields under this show as 0% on a run's line, so a pass starting there starts at shields down
const SHIELDS_SHOWN_AS_ZERO = 0.5;

/** The nearest-rank percentile: the smallest value with at least p% of them at or under it */
const percentile = (values: number[], p: number) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil((p / 100) * sorted.length) - 1)];
};

const mean = (values: number[]) => (values.length ? Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 100) / 100 : 0);

const bailMeans = (runs: RunSummary[]): BailMeans => ({
  runs: runs.length,
  meanChecks: mean(runs.map((r) => r.bailChecks.length)),
  meanInGatesSeconds: mean(runs.map((r) => r.inGatesSeconds)),
});

// Rounded like the logged figures, without the float noise of a difference
const drop = (from: number, to: number) => Math.max(0, Math.round((from - to) * 1e4) / 1e4);
const spread = (values: number[]) => (values.length ? { p50: percentile(values, 50), max: Math.max(...values) } : undefined);

const stageStops = (stops: Stop[]): StageStops => {
  const after = stops.filter((s) => s.hullAfter !== undefined && s.shieldsAfter !== undefined);
  return {
    total: stops.length,
    withSample: after.length,
    hullDrop: spread(after.map((s) => drop(s.hullAt, s.hullAfter!))),
    shieldsDrop: spread(after.map((s) => drop(s.shieldsAt, s.shieldsAfter!))),
    hullAfterMin: after.length ? Math.min(...after.map((s) => s.hullAfter!)) : undefined,
  };
};

const hits = (passes: { hit: boolean }[]): HitCount => ({ total: passes.length, hit: passes.filter((p) => p.hit).length });

export function totalRuns(runs: RunSummary[]): Totals {
  const passes = runs.flatMap((r) => r.passes);
  const hulls = runs.flatMap((r) => (r.lowestHull === undefined ? [] : [r.lowestHull]));
  const gates = runs.flatMap((r) => (r.gate === "reached" && r.gateSeconds !== undefined ? [r.gateSeconds] : []));

  const traces = new Map<string, Totals["combatTrace"][number]>();
  for (const t of runs.flatMap((r) => r.combatTrace)) {
    let sum = traces.get(t.wingman);
    if (!sum) {
      sum = { wingman: t.wingman, runs: 0, seconds: 0, shots: 0, overheats: 0, bands: [] };
      traces.set(t.wingman, sum);
    }
    sum.runs++;
    sum.seconds += t.seconds;
    sum.shots += t.shots;
    sum.overheats += t.overheats;
    for (const b of t.bands) {
      let band = sum.bands.find((s) => s.band === b.band);
      if (!band) {
        band = { band: b.band, damage: 0, fired: 0, inBand: 0 };
        sum.bands.push(band);
      }
      band.damage += b.damage;
      band.fired += b.fired;
      band.inBand += b.inBand;
    }
  }

  const met = runs.filter((r) => r.outcome === "met");
  const missed = runs.filter((r) => r.outcome === "missed");
  const byOutcome: Totals["byOutcome"] = {};
  if (met.length) byOutcome.met = bailMeans(met);
  if (missed.length) byOutcome.missed = { ...bailMeans(missed), noBailChances: missed.map((r) => r.noBailChance).sort((a, b) => a - b) };

  return {
    runs: runs.length,
    passed: runs.filter((r) => r.result === "PASS").length,
    finisherPasses: {
      ...hits(passes),
      shieldsDown: hits(passes.filter((p) => p.shieldsBefore < SHIELDS_SHOWN_AS_ZERO)),
      shieldsUp: hits(passes.filter((p) => p.shieldsBefore >= SHIELDS_SHOWN_AS_ZERO)),
    },
    lowestHull: hulls.length ? { runs: hulls.length, min: Math.min(...hulls), p50: percentile(hulls, 50) } : undefined,
    gate: { reached: gates.length, times: gates.length ? { p50: percentile(gates, 50), p90: percentile(gates, 90) } : undefined },
    gunSwaps: { count: runs.reduce((n, r) => n + r.gunSwaps.length, 0), runs: runs.filter((r) => r.gunSwaps.length).length },
    combatTrace: [...traces.values()],
    bail: { ...bailMeans(runs), checks: runs.reduce((n, r) => n + r.bailChecks.length, 0) },
    byOutcome,
    stops: Object.fromEntries(STAGES.map((stage) => [stage, stageStops(runs.flatMap((r) => r.stops.filter((s) => s.stage === stage)))])) as Record<Stage, StageStops>,
  };
}

const round = (n: number, places = 1) => String(Math.round(n * 10 ** places) / 10 ** places);

/** A block of lines: "<test> totals: …", then one indented line per figure */
export function formatTotals(test: string, t: Totals): string {
  const f = t.finisherPasses;
  const lines = [
    `${test} totals: ${t.runs} runs, ${t.passed} passed`,
    f.total
      ? `  finisher passes: ${f.hit} of ${f.total} hit; at shields 0%: ${f.shieldsDown.hit} of ${f.shieldsDown.total}, ` +
        `shields up: ${f.shieldsUp.hit} of ${f.shieldsUp.total}`
      : "  finisher passes: none",
    t.lowestHull
      ? `  lowest hull (${t.lowestHull.runs} runs): min ${round(t.lowestHull.min)}%, p50 ${round(t.lowestHull.p50)}%`
      : "  lowest hull: none seen",
    `  gate: reached in ${t.gate.reached} of ${t.runs} runs` +
      (t.gate.times ? `, p50 ${round(t.gate.times.p50)} s, p90 ${round(t.gate.times.p90)} s` : ""),
    t.gunSwaps.count ? `  gun swaps: ${t.gunSwaps.count}, in ${t.gunSwaps.runs} of ${t.runs} runs` : "  gun swaps: none",
    ...t.combatTrace.map(
      (w) =>
        `  combat trace, wingman ${w.wingman} (${w.runs} runs): ${round(w.seconds)} s, shots ${w.shots}, overheats ${w.overheats}; ` +
        `seconds with damage/fired/in band: ${w.bands.map((b) => `${b.band} ${b.damage}/${b.fired}/${b.inBand}`).join(", ")}`,
    ),
    ...STAGES.map((stage) => {
      const s = t.stops[stage];
      if (!s.total) return `  stops, ${stage}: none`;
      if (!s.withSample) return `  stops, ${stage}: ${s.total} (none with a sample ${AFTER_STOP_SECONDS} s later)`;
      return (
        `  stops, ${stage}: ${s.total} (${s.withSample} with a sample ${AFTER_STOP_SECONDS} s later): ` +
        `hull fell p50 ${round(s.hullDrop!.p50)}, max ${round(s.hullDrop!.max)} points; ` +
        `shields fell p50 ${round(s.shieldsDrop!.p50)}, max ${round(s.shieldsDrop!.max)} points; lowest hull after ${round(s.hullAfterMin!)}%`
      );
    }),
    t.bail.checks || t.bail.meanInGatesSeconds
      ? `  bail checks: ${t.bail.checks}, mean ${round(t.bail.meanChecks)} per run; in the gates: mean ${round(t.bail.meanInGatesSeconds)} s per run`
      : "  bail checks: none",
    ...(["met", "missed"] satisfies Outcome[]).flatMap((o) => {
      const b = t.byOutcome[o];
      if (!b) return [];
      const odds = "noBailChances" in b ? `; P(no bail) each: ${b.noBailChances.map((p) => `${round(p * 100, 1)}%`).join(", ")}` : "";
      return [`  outcome ${o} in ${b.runs} of ${t.runs} runs: mean ${round(b.meanChecks)} bail checks, ${round(b.meanInGatesSeconds)} s in the gates${odds}`];
    }),
  ];
  return lines.join("\n");
}
