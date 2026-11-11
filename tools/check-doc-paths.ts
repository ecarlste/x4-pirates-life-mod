// The doc-paths check (tools/doc-paths/paths.ts): fails when a doc names a repo path that doesn't
// exist, as when files leave the repo but the docs still name them. Checks docs/**/*.md (not the
// generated docs/test-plan/), README.md, tools/README.md, GLOSSARY.md and CLAUDE.md, in the git
// repo of the current folder. make test runs it when docs or the check change; also make doc-paths.
//
//   node tools/check-doc-paths.ts
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { parseArgs } from "node:util";
import { missingPaths, type Repo } from "./doc-paths/paths.ts";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-doc-paths.ts`);
  process.exit(2);
}

const git = (...args: string[]) => execFileSync("git", args, { cwd: root, encoding: "utf8" });
const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
// Tracked files and new ones not yet added, so a doc can name a file in the same change
const files = git("ls-files", "--cached", "--others", "--exclude-standard").split("\n").filter(Boolean);
const names = new Set(files.map((file) => basename(file)));

const repo: Repo = {
  exists: (path) => existsSync(join(root, path)),
  named: (name) => names.has(name),
  ignored: (path) => spawnSync("git", ["check-ignore", "-q", "--no-index", path], { cwd: root }).status === 0,
};

const docs = files
  .filter((file) => /^docs\/.*\.md$/.test(file) && !file.startsWith("docs/test-plan/"))
  .concat(["README.md", "tools/README.md", "GLOSSARY.md", "CLAUDE.md"].filter((file) => files.includes(file)))
  .sort();

const missing = docs.flatMap((doc) =>
  missingPaths(doc, readFileSync(join(root, doc), "utf8"), repo).map(({ line, path }) => `${doc}:${line}: ${path} doesn't exist`),
);
if (missing.length === 0) {
  console.log("Doc paths: ok");
} else {
  console.log(`Doc paths: ${missing.length} missing`);
  for (const line of missing) console.log(`  ${line}`);
  process.exitCode = 1;
}
