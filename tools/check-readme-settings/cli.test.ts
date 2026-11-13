import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-readme-settings.ts", import.meta.url));

// A git repo in a temp folder whose config file sets IntactOnClaim (Settings) and CaptureHoldHull
// (Tuning), and whose player README has these entries, run from its md/ folder
function run(readmeEntries: string, ...args: string[]) {
  const root = mkdtempSync(join(tmpdir(), "readme-settings-"));
  mkdirSync(join(root, "md"));
  mkdirSync(join(root, "release"));
  writeFileSync(
    join(root, "md", "apirateslife_config.xml"),
    `<mdscript><cues><library name="Defaults"><actions>` +
      `<!-- ===== Settings: x ===== --><set_value name="global.$APiratesLife_IntactOnClaim" exact="1"/>` +
      `<!-- ===== Tuning: y ===== --><set_value name="global.$APiratesLife_CaptureHoldHull" exact="75"/>` +
      `</actions></library></cues></mdscript>`,
  );
  writeFileSync(join(root, "release", "README.txt"), readmeEntries);
  spawnSync("git", ["init", "-q"], { cwd: root });
  return spawnSync(process.execPath, [cli, ...args], { cwd: join(root, "md"), encoding: "utf8" });
}

test("a README naming every setting, in its group with its default, passes", () => {
  const result = run("Settings: x\n\n  IntactOnClaim (default 1)\n\nTuning: y\n\n  CaptureHoldHull (default 75)\n");

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "README settings: ok (2 settings, release/README.txt and the config file agree)\n");
});

test("a difference fails, naming each one and both files", () => {
  const result = run("Settings: x\n\n  IntactOnClaim (default 0)\n");

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "README settings: release/README.txt's Settings and Tuning sections and md/apirateslife_config.xml differ",
      "  IntactOnClaim: the README gives default 0, the config file 1",
      "  CaptureHoldHull: in the config file only (Tuning)",
      "",
    ].join("\n"),
  );
});

test("an unknown option exits 2 with a usage line", () => {
  const result = run("", "--nope");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-readme-settings\.ts/);
});
