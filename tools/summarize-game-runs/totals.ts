// A batch of one test's runs summed up (summarize-game-runs --totals): the figures each run's
// summary (summary.ts) already holds, added or ranked across the runs. It reads no new log lines.
import type { RunSummary, WingmanTrace } from "./summary.ts";

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
  bail: { checks: number; meanChecks: number; meanInGatesSeconds: number };
  /** The runs by their split verdict, for a test that reports one; each miss's odds that none of
   * its checks bailed, lowest first, show whether it lost its rolls or had too few */
  byOutcome: { met?: BailMeans; missed?: BailMeans & { noBailChances: number[] } };
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
  const all = bailMeans(runs);

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
    bail: { checks: runs.reduce((n, r) => n + r.bailChecks.length, 0), meanChecks: all.meanChecks, meanInGatesSeconds: all.meanInGatesSeconds },
    byOutcome,
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
    `  bail checks: ${t.bail.checks}, mean ${round(t.bail.meanChecks)} per run; in the gates: mean ${round(t.bail.meanInGatesSeconds)} s per run`,
    ...(["met", "missed"] as const).flatMap((o) => {
      const b = t.byOutcome[o];
      if (!b) return [];
      const odds = "noBailChances" in b ? `; P(no bail) each: ${b.noBailChances.map((p) => `${round(p * 100)}%`).join(", ")}` : "";
      return [`  outcome ${o} in ${b.runs} of ${t.runs} runs: mean ${round(b.meanChecks)} bail checks, ${round(b.meanInGatesSeconds)} s in the gates${odds}`];
    }),
  ];
  return lines.join("\n");
}
