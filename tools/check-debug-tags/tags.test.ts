import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { FOLDERS, debugTags } from "./tags.ts";

test("names each line with a [DEBUG- tag, by file and line number", () => {
  const files = [
    { path: "md/capture.xml", text: '<cue name="A">\n  <debug_text text="\'[DEBUG-h1] hull %s\'" />\n</cue>\n' },
    { path: "aiscripts/fight.xml", text: "no probes here\n" },
    { path: "t/0001-l044.xml", text: "[DEBUG-p2] one\r\nok\r\n[DEBUG-x] two\r\n" },
  ];

  assert.deepEqual(debugTags(files), [
    { path: "md/capture.xml", line: 2, text: `<debug_text text="'[DEBUG-h1] hull %s'" />` },
    { path: "t/0001-l044.xml", line: 1, text: "[DEBUG-p2] one" },
    { path: "t/0001-l044.xml", line: 3, text: "[DEBUG-x] two" },
  ]);
});

test("only the probe tag counts, not other debug text", () => {
  const files = [{ path: "md/a.xml", text: "<debug_text text=\"'DEBUG-h1'\" />\n[debug-h1]\n[DEBUG]\n" }];

  assert.deepEqual(debugTags(files), []);
});

// make test and CI run this check only when the typescript filter matches the change, so a folder
// the filter doesn't cover could gain a probe tag unchecked
test("the typescript filter covers every folder checked", () => {
  const root = fileURLToPath(new URL("../..", import.meta.url));
  const filters: Record<string, string[]> = JSON.parse(readFileSync(join(root, ".github/test-filters.json"), "utf8"));

  assert.deepEqual(
    FOLDERS.filter((folder) => !filters.typescript.includes(`${folder}/**`)),
    [],
    "add these to the typescript filter in .github/test-filters.json, as <folder>/**",
  );
});
