// The debug-tags check (tools/check-debug-tags/tags.ts): fails when a probe log tag (`[DEBUG-<id>]`,
// from /mattpocock-skills:diagnosing-bugs) is left in a file the mod ships or the game tests run,
// naming each file and line. Checks the git repo of the current folder; make test runs it.
//
//   node tools/check-debug-tags.ts
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { CHECKED_FOLDERS, probeLines } from "./check-debug-tags/tags.ts";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-debug-tags.ts`);
  process.exit(2);
}

const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
// Tracked files and new ones not yet added, so a probe is caught before it's committed; a tracked
// file deleted but not yet committed is skipped
const paths = execFileSync("git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", ...CHECKED_FOLDERS], {
  cwd: root,
  encoding: "utf8",
})
  .split("\0")
  .filter((path) => path && existsSync(join(root, path)))
  .sort();

const probes = probeLines(paths.map((path) => ({ path, text: readFileSync(join(root, path), "utf8") })));
if (probes.length === 0) {
  console.log("Debug tags: ok");
} else {
  console.log(`Debug tags: ${probes.length} probe tag${probes.length === 1 ? "" : "s"} left in (remove each [DEBUG-…] probe once the bug is found)`);
  for (const { path, line, text } of probes) console.log(`  ${path}:${line}: ${text}`);
  process.exitCode = 1;
}
