import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { includeEntries, uppercasePaths } from "./paths.ts";

const INCLUDE = "# Paths that make up the mod\ncontent.xml\nmd\nt   # texts\n\n";

test("names each shipped path with an uppercase letter, in order", () => {
  const files = ["md/Capture.xml", "md/ok.xml", "t/0001-L044.xml", "content.xml"];

  assert.deepEqual(uppercasePaths(INCLUDE, files), ["md/Capture.xml", "t/0001-L044.xml"]);
});

test("an uppercase folder counts, the files that don't ship don't", () => {
  const files = ["md/Sub/capture.xml", "Makefile", "docs/PROJECT.md", "mdx/Notes.txt", "tests/game/md/Test.xml"];

  assert.deepEqual(uppercasePaths(INCLUDE, files), ["md/Sub/capture.xml"]);
});

// make test and CI run this check only when the typescript filter matches the change, so a shipped
// path the filter doesn't cover could gain an uppercase letter unchecked
test("the typescript filter covers every deploy.include entry", () => {
  const root = fileURLToPath(new URL("../..", import.meta.url));
  const filters: Record<string, string[]> = JSON.parse(readFileSync(join(root, ".github/test-filters.json"), "utf8"));
  const uncovered = includeEntries(readFileSync(join(root, "deploy.include"), "utf8")).filter(
    (entry) => !filters.typescript.includes(entry) && !filters.typescript.includes(`${entry}/**`),
  );

  assert.deepEqual(uncovered, [], "add these to the typescript filter in .github/test-filters.json, as <entry> or <entry>/**");
});
