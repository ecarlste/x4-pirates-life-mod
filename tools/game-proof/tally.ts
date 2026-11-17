// A chunk's results, from the lines run-game-tests.ps1 prints live as each test run reports:
// "  PASS <name> (outcome met): <detail>" or "  FAIL <name>: <detail>". Only the chunk's own test
// counts, so the log checks printed the same way (clean_log, …) don't.

export type Tally = { passed: number; failed: number; met: number; missed: number };

// A test's name as the runner matches it: the cue name and the name it reports
// (CaptureWingHoldsFire, capture_wing_holds_fire) are the same key
const key = (name: string) => name.replaceAll("_", "").toLowerCase();

export function tallyChunk(output: string, test: string): Tally {
  const tally: Tally = { passed: 0, failed: 0, met: 0, missed: 0 };
  for (const m of output.matchAll(/^\s+(PASS|FAIL) (\S+?)(?: \(outcome (met|missed)\))?:/gm)) {
    if (key(m[2]) !== key(test)) continue;
    if (m[1] === "PASS") tally.passed++;
    else tally.failed++;
    if (m[3] === "met") tally.met++;
    if (m[3] === "missed") tally.missed++;
  }
  return tally;
}

// Seconds as the runner writes them: "45 s", "5 min 55 s"
export function formatSeconds(seconds: number): string {
  const total = Math.round(seconds);
  return total < 60 ? `${total} s` : `${Math.floor(total / 60)} min ${total % 60} s`;
}
