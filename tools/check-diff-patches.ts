// The diff-patch check (tools/diff-patches/check.ts): every op of each of our diff patches in
// aiscripts/, md/ and libraries/ matches exactly one node on vanilla 8.00 and on 8.00 with SWI's
// diffs applied first, so a broken sel is caught here instead of in an X4 run. make test runs it.
//
// Reads the unpacked game and SWI files as data only. Paths come from the environment or
// deploy.config: X4_UNPACKED (unpacked vanilla 8.00's base folder, with the DLC folders next to
// it) and SWI_UNPACKED (SWI's unpacked catalogs, with ext02/ or ext/). Without X4_UNPACKED nothing
// is checked, and without SWI_UNPACKED only vanilla 8.00 is, each with a note (as in CI).
//
//   node tools/check-diff-patches.ts [--verbose]   (--verbose lists every op that matches too)
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { configValue } from "./diff-patches/config.ts";
import { checkDiffPatches, report, withKnown, type Known } from "./diff-patches/check.ts";

// Ops that don't match on 8.00 yet, each with the issue that fixes it. Reported as KNOWN, not
// failed; an entry fails the check once its op matches on both bases, so take it off then.
const KNOWN: Known[] = [
  {
    file: "aiscripts/fight.attack.object.fighter.xml",
    sel: "//do_if[@value='not $target.isclass.ship_xs and ((not this.ship.dps.lasers.all and this.ship.dps.missiles.all) or (not $firestorpedo? and this.ship.dps.missiles.all gt 0 and player.age gt $delaymissiles))']/@value",
    issue: "#121",
  },
  {
    file: "aiscripts/fight.attack.object.fighter.xml",
    sel: "//do_if[@value='not $firestorpedo? or not this.assignedcontrolled.dps.lasers.all']",
    issue: "#121",
  },
];

let values;
try {
  ({ values } = parseArgs({ options: { verbose: { type: "boolean", default: false } } }));
} catch (e) {
  console.error(`${(e as Error).message}\nUsage: node tools/check-diff-patches.ts [--verbose]`);
  process.exit(2);
}

const root = fileURLToPath(new URL("..", import.meta.url)).replace(/\/$/, "");
const [unpacked, swi] = ["X4_UNPACKED", "SWI_UNPACKED"].map((key) => configValue(key, root));
const result = withKnown(checkDiffPatches(root, unpacked, swi), KNOWN, existsSync(unpacked) && existsSync(swi));
for (const line of report(result, values.verbose)) console.log(line);
process.exitCode = result.bad.length ? 1 : 0;
