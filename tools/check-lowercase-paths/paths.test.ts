import { test } from "node:test";
import assert from "node:assert/strict";
import { uppercasePaths } from "./paths.ts";

const INCLUDE = "# Paths that make up the mod\ncontent.xml\nmd\nt   # texts\n\n";

test("names each shipped path with an uppercase letter, in order", () => {
  const files = ["md/Capture.xml", "md/ok.xml", "t/0001-L044.xml", "content.xml"];

  assert.deepEqual(uppercasePaths(INCLUDE, files), ["md/Capture.xml", "t/0001-L044.xml"]);
});

test("an uppercase folder counts, the files that don't ship don't", () => {
  const files = ["md/Sub/capture.xml", "Makefile", "docs/PROJECT.md", "mdx/Notes.txt", "tests/game/md/Test.xml"];

  assert.deepEqual(uppercasePaths(INCLUDE, files), ["md/Sub/capture.xml"]);
});

test("an entry with a trailing slash covers what's under it", () => {
  assert.deepEqual(uppercasePaths("md/\n", ["md/Capture.xml"]), ["md/Capture.xml"]);
});
