// The doc-names check (tools/check-doc-names/names.ts): fails when a doc or tool names a mod global
// ($APiratesLife_…) that the mod's scripts don't have, or a game test that was removed, as when a
// setting or test leaves the mod but the docs still name it. Retired tests come from the git history
// of the harness and the runner, so it needs the full history and fails in a shallow clone. make
// test runs it on every change (a removed name can break a file the change doesn't touch); also
// make doc-names.
//
//   node tools/check-doc-names.ts
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { gameTestNames, isCheckedFile, modGlobals, staleNames, type Known } from "./check-doc-names/names.ts";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-doc-names.ts`);
  process.exit(2);
}

const HARNESS = "tests/game/apirateslife_tests/md/apirateslife_tests.xml";
const RUNNER = "tools/run-game-tests.ps1";

const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const git = (...args: string[]) => execFileSync("git", args, { cwd: root, encoding: "utf8", maxBuffer: 1 << 28 });

if (git("rev-parse", "--is-shallow-repository").trim() === "true") {
  console.error("Doc names: this is a shallow clone, so the history of removed game tests is missing; fetch it all (git fetch --unshallow)");
  process.exit(1);
}

const read = (path: string) => (existsSync(join(root, path)) ? readFileSync(join(root, path), "utf8") : "");
// Tracked files and new ones not yet added, so a doc can name a global in the same change
const files = git("ls-files", "--cached", "--others", "--exclude-standard").split("\n").filter(Boolean);

const tests = new Set([HARNESS, RUNNER].flatMap((path) => gameTestNames(read(path))));
// Every version of the harness and runner, across renames
const everReported = [HARNESS, RUNNER].flatMap((path) =>
  gameTestNames(git("log", "--follow", "-p", "--format=", "--", path)),
);
const known: Known = {
  globals: new Set(files.filter((file) => /^(md|aiscripts)\//.test(file)).flatMap((file) => modGlobals(read(file)))),
  tests,
  retired: new Set(everReported.filter((name) => !tests.has(name))),
};

const stale = files
  .filter(isCheckedFile)
  .sort()
  .flatMap((file) => staleNames(read(file), known).map(({ line, name, why }) => `${file}:${line}: ${name} ${why}`));
if (stale.length === 0) {
  console.log("Doc names: ok");
} else {
  console.log(`Doc names: ${stale.length} stale`);
  for (const line of stale) console.log(`  ${line}`);
  console.log('Mark a name kept as history with "9.x line" or a link to the issue that removed it, on the same line.');
  process.exitCode = 1;
}
