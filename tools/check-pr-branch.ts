// The PR branch check: fails a PR whose head branch is research/<name> or prototype/<name>. Those
// branches hold research or a prototype and are never merged (docs/PROJECT.md, Workflow rules);
// work on a ticket goes on an issue-<n> branch. CI runs it on every PR (.github/workflows/pr-branch.yml).
//
//   node tools/check-pr-branch.ts <branch>
import { parseArgs } from "node:util";

// Each never-merged prefix and what its branches hold
const NEVER_MERGED: Record<string, string> = { "research/": "research", "prototype/": "a prototype" };

let branch: string | undefined;
try {
  [branch] = parseArgs({ options: {}, allowPositionals: true }).positionals;
  if (!branch) throw new Error("No branch given");
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-pr-branch.ts <branch>`);
  process.exit(2);
}

const prefix = Object.keys(NEVER_MERGED).find((p) => branch.startsWith(p));
if (prefix) {
  console.log(
    `::error::${branch} holds ${NEVER_MERGED[prefix]} and is never merged, so it can't be a PR. ` +
      "Put the work on an issue-<n> branch (docs/agents/issue-tracker.md, Starting a ticket).",
  );
  process.exitCode = 1;
} else {
  console.log(`OK: ${branch}`);
}
