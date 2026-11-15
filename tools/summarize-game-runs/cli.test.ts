import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../summarize-game-runs.ts", import.meta.url));
const run = (...args: string[]) => spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });

const result = (time: string, outcome: string) =>
  `[General] ${time} *** Context:md.APiratesLife_Tests.Report: [apirateslife-test] ${outcome} capture_wing_breaks_full_shields: after 9 s\n`;

// A folder of traces as the runner leaves them, written out of order
function runsFolder(): string {
  const dir = join(mkdtempSync(join(tmpdir(), "summarize-game-runs-")), "runs");
  mkdirSync(dir);
  writeFileSync(join(dir, "capture_wing_breaks_full_shields-10.log"), result("30.00", "FAIL"));
  writeFileSync(join(dir, "capture_wing_breaks_full_shields-2.log"), result("20.00", "PASS"));
  writeFileSync(join(dir, "capture_wing_breaks_full_shields-1.log"), result("10.00", "PASS"));
  writeFileSync(join(dir, "bail_raises_bailed-1.log"), result("5.00", "PASS"));
  writeFileSync(join(dir, "notes.txt"), "not a trace");
  return dir;
}

test("a folder prints one line per trace, by test name, then run number", () => {
  const out = run(runsFolder());

  assert.equal(out.status, 0, out.stderr);
  assert.deepEqual(
    out.stdout.trimEnd().split("\n").map((l) => l.split(":")[0]),
    [
      "bail_raises_bailed-1 PASS",
      "capture_wing_breaks_full_shields-1 PASS",
      "capture_wing_breaks_full_shields-2 PASS",
      "capture_wing_breaks_full_shields-10 FAIL",
    ],
  );
});

test("files can be named one by one, in the order given", () => {
  const dir = runsFolder();
  const out = run(join(dir, "capture_wing_breaks_full_shields-2.log"), join(dir, "bail_raises_bailed-1.log"));

  assert.equal(out.status, 0, out.stderr);
  assert.match(out.stdout, /^capture_wing_breaks_full_shields-2 PASS: .*\nbail_raises_bailed-1 PASS: .*\n$/);
});

test("a folder without traces fails, naming it", () => {
  const dir = mkdtempSync(join(tmpdir(), "summarize-game-runs-empty-"));
  const out = run(dir);

  assert.equal(out.status, 1);
  assert.match(out.stderr, new RegExp(`No run traces \\(\\*\\.log\\) in ${dir.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
});

test("an unknown option exits 2 with a usage line", () => {
  const out = run("--nope");

  assert.equal(out.status, 2);
  assert.match(out.stderr, /Usage: node tools\/summarize-game-runs\.ts/);
});
