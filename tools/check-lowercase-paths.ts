// The lowercase-paths check (tools/check-lowercase-paths/paths.ts): fails when a path the mod ships
// (an entry in deploy.include, or anything under one) has an uppercase letter, naming each. X4 3.0+
// expects lowercase names, and a mixed-case loose file loads on one setup and silently not on
// another. Checks the git repo of the current folder; make test runs it.
//
//   node tools/check-lowercase-paths.ts
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { uppercasePaths } from "./check-lowercase-paths/paths.ts";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-lowercase-paths.ts`);
  process.exit(2);
}

const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
// Tracked files and new ones not yet added, so a new file is caught before it's committed
const files = execFileSync("git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard"], { cwd: root, encoding: "utf8" })
  .split("\0")
  .filter(Boolean);

const bad = uppercasePaths(readFileSync(join(root, "deploy.include"), "utf8"), files);
if (bad.length === 0) {
  console.log("Lowercase paths: ok");
} else {
  console.log(`Lowercase paths: ${bad.length} shipped with uppercase letters (X4 expects lowercase)`);
  for (const path of bad) console.log(`  ${path}`);
  process.exitCode = 1;
}
