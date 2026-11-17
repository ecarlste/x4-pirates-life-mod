// A proof's chunks: each test's runs split into make game-test calls that each fit the hold budget
// (docs/testing.md, Keep each hold short), from the runner's own worst-case estimates
// (run-game-tests.ps1 -HoldEstimateOnly), so a chunk is never refused. One trace set: the first
// chunk clears the label's traces and every later one appends (-RunsAppend).

// What run-game-tests.ps1 -HoldEstimateOnly prints: the hold budget and the game's start in
// seconds, and each test's worst case for one run (0 for a test that reports from its own actions)
export type Estimates = { budget: number; gameStart: number; tests: { name: string; seconds: number }[] };

export type Chunk = {
  test: string;
  // How many runs, and the number of the first in the test's whole proof (1-based)
  runs: number;
  firstRun: number;
  // The chunk's worst-case hold in seconds, and whether it's over the budget: a test whose one run
  // can't fit still runs, alone
  hold: number;
  long: boolean;
  // The runner's arguments for it (make game-test RUNNER_ARGS)
  args: string[];
};

// Within a millisecond counts as fitting, so a SETA test's fractional seconds don't lose a run
const fits = (seconds: number, budget: number) => Math.round(seconds * 1000) <= budget * 1000;

export function planChunks(estimates: Estimates, runs: number, label: string): Chunk[] {
  const { budget, gameStart } = estimates;
  const chunks: Chunk[] = [];
  for (const { name, seconds } of estimates.tests) {
    let size = 1;
    if (seconds === 0) size = runs;
    else while (size < runs && fits(gameStart + (size + 1) * seconds, budget)) size++;
    for (let first = 1; first <= runs; first += size) {
      const count = Math.min(size, runs - first + 1);
      const hold = gameStart + count * seconds;
      const args = ["-Test", name, "-Repeat", String(count), "-RunsLabel", label];
      if (chunks.length > 0) args.push("-RunsAppend");
      chunks.push({ test: name, runs: count, firstRun: first, hold, long: !fits(hold, budget), args });
    }
  }
  return chunks;
}
