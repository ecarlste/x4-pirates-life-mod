import { test } from "node:test";
import assert from "node:assert/strict";
import { compareSettings, configSettings, readmeSettings } from "./settings.ts";

const config = (body: string) => `<mdscript><cues><library name="Defaults"><actions>${body}</actions></library></cues></mdscript>`;
const setting = (name: string, value: string) => `<set_value name="global.$APiratesLife_${name}" exact="${value}"/>`;

const README = `Settings and Tuning
-------------------

Some prose naming IntactOnClaim (default 0), which isn't an entry.

Settings: how hard a capture is

  IntactOnClaim (default 1)
    What it does. 0 or 1.

  CapturePressureCap (default 80)
    What it does.

Tuning: change these only if you know why

  CaptureHoldHull (default 75)
    What it does.


Known issues
------------

  NotASetting (default 3)
`;

test("the README's entries, by group, only inside the Settings and Tuning groups", () => {
  assert.deepEqual(
    readmeSettings(README),
    new Map([
      ["IntactOnClaim", { group: "Settings", value: "1" }],
      ["CapturePressureCap", { group: "Settings", value: "80" }],
      ["CaptureHoldHull", { group: "Tuning", value: "75" }],
    ]),
  );
});

test("the config file's settings, grouped by the banner comment above them", () => {
  const xml = config(
    `<!-- ===== Settings: how hard a capture is ===== -->${setting("IntactOnClaim", "1")}<!-- a value's own comment -->` +
      `${setting("CapturePressureCap", "80")}<!-- ===== Tuning: change these only if you know why ===== -->${setting("CaptureHoldHull", "75")}`,
  );

  assert.deepEqual(
    configSettings(xml),
    new Map([
      ["IntactOnClaim", { group: "Settings", value: "1" }],
      ["CapturePressureCap", { group: "Settings", value: "80" }],
      ["CaptureHoldHull", { group: "Tuning", value: "75" }],
    ]),
  );
});

test("a config setting above every banner has no group", () => {
  assert.deepEqual(configSettings(config(setting("IntactOnClaim", "1"))), new Map([["IntactOnClaim", { group: "", value: "1" }]]));
});

test("the same settings, groups and defaults agree", () => {
  const both = new Map([
    ["IntactOnClaim", { group: "Settings", value: "1" }],
    ["CaptureFearDecayFactor", { group: "Tuning", value: "0.5" }],
  ]);
  assert.deepEqual(compareSettings(both, new Map([...both, ["CaptureFearDecayFactor", { group: "Tuning", value: ".50" }]])), []);
});

test("each difference is one line: a missing setting either way, another group or another default", () => {
  const readme = new Map([
    ["IntactOnClaim", { group: "Settings", value: "1" }],
    ["CaptureHoldHull", { group: "Settings", value: "70" }],
    ["Typo", { group: "Tuning", value: "5" }],
  ]);
  const fromConfig = new Map([
    ["IntactOnClaim", { group: "Settings", value: "1" }],
    ["CaptureHoldHull", { group: "Tuning", value: "75" }],
    ["CaptureFloorHull", { group: "Tuning", value: "35" }],
    ["Ungrouped", { group: "", value: "1" }],
  ]);

  assert.deepEqual(compareSettings(readme, fromConfig), [
    "CaptureHoldHull: under Settings in the README, Tuning in the config file",
    "CaptureHoldHull: the README gives default 70, the config file 75",
    "Typo: in the README only",
    "CaptureFloorHull: in the config file only (Tuning)",
    "Ungrouped: in the config file only (under no Settings or Tuning banner)",
  ]);
});
