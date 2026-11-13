import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-settings-defaults.ts", import.meta.url));

// A git repo in a temp folder whose config file sets these values and whose loader's $Defaults has
// these, run from its md/ folder
function run(configValues: Record<string, string>, loaderValues: Record<string, string>, ...args: string[]) {
  const root = mkdtempSync(join(tmpdir(), "settings-defaults-"));
  mkdirSync(join(root, "md"));
  const lines = Object.entries(configValues).map(([name, value]) => `<set_value name="global.$APiratesLife_${name}" exact="${value}"/>`);
  writeFileSync(
    join(root, "md", "apirateslife_config.xml"),
    `<mdscript><cues><library name="Defaults"><actions>${lines.join("")}</actions></library></cues></mdscript>`,
  );
  const table = Object.entries(loaderValues).map(([name, value]) => `$${name} = ${value}`);
  writeFileSync(
    join(root, "md", "apirateslife_settings.xml"),
    `<mdscript><cues><library name="Validate"><actions><set_value name="$Defaults" exact="table[${table.join(", ")}]"/></actions></library></cues></mdscript>`,
  );
  spawnSync("git", ["init", "-q"], { cwd: root });
  return spawnSync(process.execPath, [cli, ...args], { cwd: join(root, "md"), encoding: "utf8" });
}

test("matching copies pass, counting the settings", () => {
  const result = run({ IntactOnClaim: "1", CaptureHoldHull: "75" }, { IntactOnClaim: "1", CaptureHoldHull: "75" });

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Settings defaults: ok (2 settings, the config file and the loader agree)\n");
});

test("a difference fails, naming each one and both files", () => {
  const result = run({ IntactOnClaim: "1", CaptureHoldHull: "75" }, { IntactOnClaim: "0" });

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "Settings defaults: md/apirateslife_config.xml and the $Defaults table in md/apirateslife_settings.xml differ",
      "  IntactOnClaim: the config file gives 1, the loader 0",
      "  CaptureHoldHull: in the config file only",
      "",
    ].join("\n"),
  );
});

test("an unknown option exits 2 with a usage line", () => {
  const result = run({}, {}, "--nope");

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage: node tools\/check-settings-defaults\.ts/);
});
