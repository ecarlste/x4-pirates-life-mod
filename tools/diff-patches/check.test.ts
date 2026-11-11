import { test } from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { checkDiffPatches, report, withKnown } from "./check.ts";

const fixtures = fileURLToPath(new URL("fixtures", import.meta.url));
const mod = join(fixtures, "mod");
const unpacked = join(fixtures, "unpacked", "base"); // DLC folders sit next to it
const swi = join(fixtures, "swi"); // 0.91's layout: ext/ and ext02/
const swi090 = join(fixtures, "swi-0.90"); // 0.90's: ext/ only

const VANILLA = "vanilla 8.00";
const SWI = "8.00 + SWI";

test("each op must match exactly once on vanilla 8.00 (with the DLCs' diffs) and on 8.00 with SWI's diffs too", () => {
  const { notes, bad } = checkDiffPatches(mod, unpacked, swi);
  const ok = (base: string, file: string, op: string) => `${file} on ${base}: ${op} matches 1 node`;
  const ai = ["<add sel=\"//do_if[@value='dlc']\">", "<replace sel=\"//do_if[@value='old']/@value\">"];
  const script = [
    "<add sel=\"//cue[@name='Start']/actions\">",
    "<add sel=\"//cue[@name='Ours']\">",
    "<add sel=\"//cue[@name='DlcCue']\">",
    "<remove sel=\"//cue[@name='Second']/actions/x[@v='a'][2]\">",
    "<replace sel=\"//x[@v='a']/@v\">",
  ];
  assert.deepEqual(notes, [
    ...ai.map((op) => ok(VANILLA, "aiscripts/ai.xml", op)),
    ok(SWI, "aiscripts/ai.xml", ai[0]),
    // The DLC's full file at the game's path doesn't replace the game's
    ok(VANILLA, "libraries/lib.xml", "<add sel=\"/lib/entry[@name='base']\">"),
    ok(SWI, "libraries/lib.xml", "<add sel=\"/lib/entry[@name='base']\">"),
    ok(VANILLA, "md/dlc_own.xml", "<add sel=\"//cue[@name='DlcOwnCue']\">"),
    ok(SWI, "md/dlc_own.xml", "<add sel=\"//cue[@name='DlcOwnCue']\">"),
    // A base's own diff op that doesn't match is noted once, before the file's results
    `md/script.xml: ego_dlc_one's diff: <remove sel="//cue[@name='NoSuchCue']"> matches 0 nodes, skipped as X4 skips it`,
    ...script.map((op) => ok(VANILLA, "md/script.xml", op)),
    ...script.map((op) => ok(SWI, "md/script.xml", op)),
    ok(SWI, "md/script.xml", "<add sel=\"//cue[@name='SwiCue']\">"),
  ]);
  assert.deepEqual(bad, [
    `aiscripts/ai.xml on ${SWI}: <replace sel="//do_if[@value='old']/@value"> matches 0 nodes`,
    `libraries/nothing.xml on ${VANILLA}: no libraries/nothing.xml to patch`,
    `libraries/nothing.xml on ${SWI}: no libraries/nothing.xml to patch`,
    `md/script.xml on ${VANILLA}: <add sel="//cue[@name='SwiCue']"> matches 0 nodes`,
    // More than one match fails too
    `md/script.xml on ${VANILLA}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
    `md/script.xml on ${SWI}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
  ]);
});

test("SWI 0.90, with only ext/, is applied from there", () => {
  const { notes, bad } = checkDiffPatches(mod, unpacked, swi090);
  // ext/ has no AI script diff, so ours matches on SWI too
  assert.ok(notes.includes(`aiscripts/ai.xml on ${SWI}: <replace sel="//do_if[@value='old']/@value"> matches 1 node`));
  assert.ok(bad.includes(`md/script.xml on ${SWI}: <add sel="//cue[@name='SwiCue']"> matches 0 nodes`));
});

test("without SWI_UNPACKED, only vanilla 8.00 is checked, with a note", () => {
  const { notes, bad } = checkDiffPatches(mod, unpacked, "");
  assert.equal(notes[0], `${SWI} not checked: SWI_UNPACKED not found`);
  assert.ok(notes.every((line) => !line.includes(SWI) || line === notes[0]));
  assert.equal(bad.length, 3);
});

test("without X4_UNPACKED, nothing is checked, with a note", () => {
  assert.deepEqual(checkDiffPatches(mod, "", swi), {
    notes: ["not checked: X4_UNPACKED not found"],
    bad: [],
  });
  assert.deepEqual(checkDiffPatches(mod, join(fixtures, "no-such-folder"), swi).bad, []);
});

test("a known mismatch is reported as known, not failed, and a known entry that matches now fails", () => {
  const result = withKnown(checkDiffPatches(mod, unpacked, swi), [
    { file: "aiscripts/ai.xml", sel: "//do_if[@value='old']/@value", issue: "#1" },
    { file: "md/script.xml", sel: "//cue[@name='Start']/actions", issue: "#2" },
  ]);
  assert.deepEqual(result.known, [
    `#1: aiscripts/ai.xml on ${SWI}: <replace sel="//do_if[@value='old']/@value"> matches 0 nodes`,
  ]);
  assert.deepEqual(result.bad, [
    `libraries/nothing.xml on ${VANILLA}: no libraries/nothing.xml to patch`,
    `libraries/nothing.xml on ${SWI}: no libraries/nothing.xml to patch`,
    `md/script.xml on ${VANILLA}: <add sel="//cue[@name='SwiCue']"> matches 0 nodes`,
    `md/script.xml on ${VANILLA}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
    `md/script.xml on ${SWI}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
    `md/script.xml: sel="//cue[@name='Start']/actions" is listed as a known mismatch (#2) but matches on every base now: take it off the list`,
  ]);
});

test("known entries are only judged stale when both bases were checked", () => {
  const known = [{ file: "aiscripts/ai.xml", sel: "//do_if[@value='old']/@value", issue: "#1" }];
  assert.deepEqual(withKnown(checkDiffPatches(mod, unpacked, ""), known, false).bad.length, 3);
  assert.deepEqual(withKnown(checkDiffPatches(mod, "", ""), known, false), {
    notes: ["not checked: X4_UNPACKED not found"],
    known: [],
    bad: [],
  });
});

test("the report counts the ops that match, lists everything else, and says whether the check passed", () => {
  const result = withKnown(checkDiffPatches(mod, unpacked, swi), [
    { file: "aiscripts/ai.xml", sel: "//do_if[@value='old']/@value", issue: "#1" },
  ]);
  assert.deepEqual(report(result), [
    "Diff patches: FAIL",
    "  18 ops match exactly once",
    `  md/script.xml: ego_dlc_one's diff: <remove sel="//cue[@name='NoSuchCue']"> matches 0 nodes, skipped as X4 skips it`,
    `  KNOWN #1: aiscripts/ai.xml on ${SWI}: <replace sel="//do_if[@value='old']/@value"> matches 0 nodes`,
    `  FAIL libraries/nothing.xml on ${VANILLA}: no libraries/nothing.xml to patch`,
    `  FAIL libraries/nothing.xml on ${SWI}: no libraries/nothing.xml to patch`,
    `  FAIL md/script.xml on ${VANILLA}: <add sel="//cue[@name='SwiCue']"> matches 0 nodes`,
    `  FAIL md/script.xml on ${VANILLA}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
    `  FAIL md/script.xml on ${SWI}: <remove sel="//cue[@name='Start' or @name='Second']"> matches 2 nodes`,
  ]);
  assert.equal(report(result, true).length, report(result).length + 18);
  assert.deepEqual(report({ notes: ["not checked: X4_UNPACKED not found"], known: [], bad: [] }), [
    "Diff patches: ok",
    "  not checked: X4_UNPACKED not found",
  ]);
});
