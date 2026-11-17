import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../game-proof.ts", import.meta.url));

// A sandbox with a fake runner, which prints the estimates (or fails, as on an unknown test), and a
// fake make, which logs each game-test call's RUNNER_ARGS and prints the lines the real runner
// prints live for each run: the chunk's results come from $RESULTS, one line per call, each run's
// result separated by "|"; a call whose line has "exit1" fails as make game-test does
type Fake = { estimates?: string; results: string[] };
function sandbox({ estimates, results }: Fake) {
  const dir = mkdtempSync(join(tmpdir(), "game-proof-"));
  const runner = join(dir, "runner");
  const make = join(dir, "make");
  writeFileSync(join(dir, "results"), results.join("\n") + "\n");
  writeFileSync(
    runner,
    estimates === undefined
      ? `#!/bin/bash\necho "No game test named nope. The tests: a, b" >&2\nexit 1\n`
      : `#!/bin/bash\necho "$*" > "${dir}/estimate-args"\necho '${estimates}'\n`,
  );
  writeFileSync(
    make,
    `#!/bin/bash
if [ -n "\${GAME_TEST_RUNNER+x}" ]; then echo "GAME_TEST_RUNNER leaked" >> "${dir}/leaks"; fi
for a in "$@"; do case "$a" in RUNNER_ARGS=*) echo "\${a#RUNNER_ARGS=}" >> "${dir}/calls";; esac; done
n=$(wc -l < "${dir}/calls")
line=$(sed -n "\${n}p" "${dir}/results")
status=0
IFS='|' read -ra runs <<< "$line"
for r in "\${runs[@]}"; do
  if [ "$r" = exit1 ]; then status=1; else echo "  $r"; fi
done
echo "  PASS clean_log: no errors"
exit $status
`,
  );
  chmodSync(runner, 0o755);
  chmodSync(make, 0o755);
  const run = (...args: string[]) =>
    spawnSync(process.execPath, [cli, ...args], {
      encoding: "utf8",
      env: { ...process.env, GAME_TEST_RUNNER: runner, MAKE: make },
    });
  const calls = () => (existsSync(join(dir, "calls")) ? readFileSync(join(dir, "calls"), "utf8").trimEnd().split("\n") : []);
  const estimateArgs = () => readFileSync(join(dir, "estimate-args"), "utf8").trim();
  const leaked = () => existsSync(join(dir, "leaks"));
  return { run, calls, estimateArgs, leaked };
}

const fight = (seconds = 120) =>
  JSON.stringify({ budget: 300, gameStart: 55, tests: [{ name: "fight", seconds }] });
const lines = (stdout: string) => stdout.split("\n").filter((l) => l.startsWith("game-proof:"));

test("runs the proof in chunks within the hold budget, one trace set, a line per chunk", () => {
  const fake = sandbox({
    estimates: fight(),
    results: [
      "PASS fight (outcome met): bailed|PASS fight (outcome missed): timed out",
      "PASS fight (outcome met): bailed|PASS fight (outcome met): bailed",
      "PASS fight (outcome met): bailed",
    ],
  });
  const out = fake.run("--test", "fight", "--runs", "5", "--label", "base");

  assert.equal(out.status, 0, out.stderr + out.stdout);
  assert.equal(fake.estimateArgs(), "-HoldEstimateOnly -Test fight");
  // make game-test reads its own runner command: one from the environment would beat its ?= and
  // lose its $(wslpath ...) to make's expansion
  assert.equal(fake.leaked(), false);
  assert.deepEqual(fake.calls(), [
    "-Test fight -Repeat 2 -RunsLabel base",
    "-Test fight -Repeat 2 -RunsLabel base -RunsAppend",
    "-Test fight -Repeat 1 -RunsLabel base -RunsAppend",
  ]);
  const chunkLines = lines(out.stdout).filter((l) => /chunk \d+ of/.test(l));
  assert.equal(chunkLines.length, 3);
  assert.match(chunkLines[0], /chunk 1 of 3: fight runs 1-2 of 5: passed 2, failed 0; outcomes met 1, missed 1/);
  assert.match(chunkLines[2], /chunk 3 of 3: fight run 5 of 5: passed 1, failed 0; outcomes met 1, missed 0/);
  // The runner's own lines still show, and its log checks don't count as runs
  assert.match(out.stdout, /PASS clean_log/);
  assert.doesNotMatch(out.stdout, /long hold|over the budget/);
  assert.match(out.stdout, /node tools\/summarize-game-runs\.ts --totals tests\/game\/runs\/base/);
});

test("a failed run stops the proof after its chunk, saying how to run on", () => {
  const fake = sandbox({
    estimates: fight(),
    results: ["PASS fight (outcome met): bailed|FAIL fight (outcome missed): destroyed|exit1", "PASS fight: ok|PASS fight: ok"],
  });
  const out = fake.run("--test", "fight", "--runs", "4", "--label", "base");

  assert.equal(out.status, 1);
  assert.equal(fake.calls().length, 1);
  assert.match(out.stdout, /chunk 1 of 2: fight runs 1-2 of 4: FAILED, passed 1, failed 1; outcomes met 1, missed 1/);
  assert.match(out.stdout, /stopped: chunk 1 failed .*KEEP_GOING=1/);
});

test("a missed outcome alone doesn't stop the proof", () => {
  const fake = sandbox({
    estimates: fight(),
    results: ["PASS fight (outcome missed): timed out|PASS fight (outcome missed): timed out", "PASS fight (outcome met): bailed"],
  });
  const out = fake.run("--test", "fight", "--runs", "3", "--label", "base");

  assert.equal(out.status, 0, out.stdout);
  assert.equal(fake.calls().length, 2);
});

test("--keep-going runs every chunk past a failure, and still fails at the end", () => {
  const fake = sandbox({ estimates: fight(), results: ["FAIL fight: destroyed|exit1", "PASS fight: ok", "PASS fight: ok"] });
  const out = fake.run("--test", "fight", "--runs", "3", "--label", "base", "--keep-going");

  assert.equal(out.status, 1);
  assert.equal(fake.calls().length, 2);
  assert.doesNotMatch(out.stdout, /stopped/);
  assert.match(out.stdout, /chunk 2 of 2: fight run 3 of 3: passed 1/);
});

test("a test whose one run is over the budget runs one run per chunk, with the long hold called out", () => {
  const fake = sandbox({ estimates: fight(300), results: ["PASS fight: ok", "PASS fight: ok"] });
  const out = fake.run("--test", "fight", "--runs", "2", "--label", "base");

  assert.equal(out.status, 0, out.stdout);
  assert.deepEqual(fake.calls(), ["-Test fight -Repeat 1 -RunsLabel base", "-Test fight -Repeat 1 -RunsLabel base -RunsAppend"]);
  assert.match(out.stdout, /fight: one run could hold the game for up to 5 min 55 s, over the budget/);
  assert.match(out.stdout, /chunk 1 of 2: .*a long hold of up to 5 min 55 s/);
});

test("a test the runner can't estimate, such as an unknown name, runs nothing", () => {
  const fake = sandbox({ results: [] });
  const out = fake.run("--test", "nope", "--runs", "2", "--label", "base");

  assert.equal(out.status, 1);
  assert.match(out.stderr, /No game test named nope/);
  assert.deepEqual(fake.calls(), []);
});

test("bad arguments exit 2 with a usage line", () => {
  const fake = sandbox({ estimates: fight(), results: [] });
  for (const args of [
    ["--nope"],
    ["--runs", "2", "--label", "base"],
    ["--test", "fight", "--runs", "0", "--label", "base"],
    ["--test", "fight;rm", "--runs", "2", "--label", "base"],
    ["--test", "fight", "--runs", "2", "--label", "../x"],
  ]) {
    const out = fake.run(...args);
    assert.equal(out.status, 2, args.join(" "));
    assert.match(out.stderr, /^Usage: node tools\/game-proof\.ts/m);
  }
  assert.deepEqual(fake.calls(), []);
});
