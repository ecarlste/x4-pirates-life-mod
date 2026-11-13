// The README-settings check (tools/check-readme-settings/settings.ts): fails when the player
// README's Settings and Tuning sections (release/README.txt) and the config file
// (md/apirateslife_config.xml) disagree: a setting only one names, one in another group, or another
// default. Checks the git repo of the current folder; make test runs it.
//
//   node tools/check-readme-settings.ts
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { compareSettings, configSettings, readmeSettings } from "./check-readme-settings/settings.ts";

const README = "release/README.txt";
const CONFIG = "md/apirateslife_config.xml";

try {
  parseArgs({ options: {} });
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-readme-settings.ts`);
  process.exit(2);
}

const root = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim();
const fromConfig = configSettings(readFileSync(join(root, CONFIG), "utf8"));
const problems = compareSettings(readmeSettings(readFileSync(join(root, README), "utf8")), fromConfig);
if (problems.length === 0) {
  console.log(`README settings: ok (${fromConfig.size} settings, ${README} and the config file agree)`);
} else {
  console.log(`README settings: ${README}'s Settings and Tuning sections and ${CONFIG} differ`);
  for (const problem of problems) console.log(`  ${problem}`);
  process.exitCode = 1;
}
