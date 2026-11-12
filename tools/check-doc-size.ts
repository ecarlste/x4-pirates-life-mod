// The doc-size check: fails when docs/PROJECT.md goes over its size budget. CLAUDE.md loads all of
// it on every agent turn, so it holds rules and pointers only; detail goes in the docs its
// "Where to look" table names. make test runs it with the TypeScript tools.
//
//   node tools/check-doc-size.ts
import { statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

const DOC = "docs/PROJECT.md";
// Just above PROJECT.md after it was slimmed to rules and pointers (7,470 bytes, #146). Move detail
// out rather than raise it.
const BUDGET = 8192;

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-doc-size.ts`);
  process.exit(2);
}

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const bytes = statSync(join(root, DOC)).size;
if (bytes <= BUDGET) {
  console.log(`Doc size: ok (${DOC} ${bytes} of ${BUDGET} bytes)`);
} else {
  console.log(`Doc size: ${DOC} is ${bytes} bytes, over its budget of ${BUDGET}.`);
  console.log("  CLAUDE.md loads it on every agent turn. Move detail into a doc its \"Where to look\" table");
  console.log("  names (or a new one listed there), leaving a pointer, rather than raising the budget.");
  process.exitCode = 1;
}
