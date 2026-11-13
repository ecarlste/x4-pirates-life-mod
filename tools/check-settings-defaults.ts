// The settings-defaults check (tools/check-settings-defaults/defaults.ts): fails when the config
// file's defaults (md/apirateslife_config.xml) and the loader's own copy (the $Defaults table in
// md/apirateslife_settings.xml, used when X4 skipped the config file) differ, naming each
// difference. Checks the git repo of the current folder; make test runs it.
//
//   node tools/check-settings-defaults.ts
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { compareDefaults, configDefaults, loaderDefaults } from "./check-settings-defaults/defaults.ts";

const CONFIG = "md/apirateslife_config.xml";
const LOADER = "md/apirateslife_settings.xml";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-settings-defaults.ts`);
  process.exit(2);
}

const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const fromConfig = configDefaults(readFileSync(join(root, CONFIG), "utf8"));
const problems = compareDefaults(fromConfig, loaderDefaults(readFileSync(join(root, LOADER), "utf8")));
if (problems.length === 0) {
  console.log(`Settings defaults: ok (${fromConfig.size} settings, the config file and the loader agree)`);
} else {
  console.log(`Settings defaults: ${CONFIG} and the $Defaults table in ${LOADER} differ`);
  for (const problem of problems) console.log(`  ${problem}`);
  process.exitCode = 1;
}
