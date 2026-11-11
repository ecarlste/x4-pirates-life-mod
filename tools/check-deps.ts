// node_modules matches package-lock.json (tools/check-deps/deps.ts). make test runs it before the
// other TypeScript tools, so a missing or stale package fails here, named, not as "Cannot find package".
//
//   node tools/check-deps.ts
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { checkDeps } from "./check-deps/deps.ts";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-deps.ts`);
  process.exit(2);
}

const tools = dirname(fileURLToPath(import.meta.url));
const problems = checkDeps(dirname(tools), tools);
if (problems.length === 0) {
  console.log("Dependencies: ok");
} else {
  console.error("node_modules doesn't match package-lock.json:");
  for (const problem of problems) console.error(`  ${problem}`);
  console.error(
    "Run `make setup` in the main checkout (or `npm install` in this worktree if your branch changes package.json).",
  );
  process.exitCode = 1;
}
