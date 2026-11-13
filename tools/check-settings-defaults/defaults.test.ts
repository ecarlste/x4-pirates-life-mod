import { test } from "node:test";
import assert from "node:assert/strict";
import { compareDefaults, configDefaults, loaderDefaults } from "./defaults.ts";

// A config file shaped like md/apirateslife_config.xml
const config = (lines: string) => `<?xml version="1.0" encoding="utf-8"?>
<mdscript name="APiratesLife_Config">
  <cues>
    <library name="Defaults" purpose="run_actions">
      <actions>
${lines}
      </actions>
    </library>
  </cues>
</mdscript>`;

// A loader shaped like md/apirateslife_settings.xml
const loader = (table: string) => `<?xml version="1.0" encoding="utf-8"?>
<mdscript name="APiratesLife_Settings">
  <cues>
    <library name="Validate" purpose="run_actions">
      <actions>
        <set_value name="$Other" exact="table[$IntactOnClaim = 7]"/>
        <set_value name="$Defaults" exact="${table}"/>
      </actions>
    </library>
  </cues>
</mdscript>`;

test("configDefaults reads each global the Defaults library sets, by setting name", () => {
  const xml = config(`
        <!-- a comment -->
        <set_value name="global.$APiratesLife_IntactOnClaim" exact="1"/>
        <set_value name="global.$APiratesLife_CaptureFearDecayFactor" exact="0.5"/>`);

  assert.deepEqual(
    configDefaults(xml),
    new Map([
      ["IntactOnClaim", "1"],
      ["CaptureFearDecayFactor", "0.5"],
    ]),
  );
});

test("loaderDefaults reads the $Defaults table in the Validate library, over lines too", () => {
  const xml = loader(`table[
          $IntactOnClaim = 1,
          $CaptureFearDecayFactor = 0.5
        ]`);

  assert.deepEqual(
    loaderDefaults(xml),
    new Map([
      ["IntactOnClaim", "1"],
      ["CaptureFearDecayFactor", "0.5"],
    ]),
  );
});

test("loaderDefaults throws when the loader has no $Defaults table", () => {
  assert.throws(() => loaderDefaults(loader("[1, 2]")), /\$Defaults/);
});

test("matching defaults give no problems; numbers compare by value", () => {
  const a = new Map([
    ["IntactOnClaim", "1"],
    ["CaptureFearDecayFactor", "0.5"],
  ]);
  const b = new Map([
    ["IntactOnClaim", "1"],
    ["CaptureFearDecayFactor", "0.50"],
  ]);

  assert.deepEqual(compareDefaults(a, b), []);
});

test("compareDefaults names each differing value and each setting only one copy has", () => {
  const fromConfig = new Map([
    ["IntactOnClaim", "1"],
    ["CaptureHoldHull", "75"],
    ["CaptureFloorHull", "35"],
  ]);
  const fromLoader = new Map([
    ["IntactOnClaim", "1"],
    ["CaptureHoldHull", "70"],
    ["CapturePressureCap", "80"],
  ]);

  assert.deepEqual(compareDefaults(fromConfig, fromLoader), [
    "CaptureHoldHull: the config file gives 75, the loader 70",
    "CaptureFloorHull: in the config file only",
    "CapturePressureCap: in the loader only",
  ]);
});
