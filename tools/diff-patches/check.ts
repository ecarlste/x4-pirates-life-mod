// The diff-patch check: every op of each of our diff patches (an XML file in aiscripts/, md/ or
// libraries/ with a <diff> root) matches exactly one node, on two bases:
//
// - vanilla 8.00: the game's file (X4_UNPACKED, the unpacked base folder), with each DLC's diff
//   of it applied in turn (the ego_dlc_* folders next to X4_UNPACKED, in name order), or a DLC's
//   own file where the game has none;
// - 8.00 + SWI: that, with SWI's diff at the same path applied after (SWI_UNPACKED: ext02/'s
//   when it has one, since 0.91's ext_02 catalog replaces ext_01's whole file, else ext/'s).
// A full (non-diff) file at a path an earlier layer has is left out: X4 merges those, as the
// DLCs' own icons.xml, and the check doesn't model that, so a sel on what they add isn't found.
//
// Our ops apply in order, as X4 applies them, so a later op is counted on what the earlier ones
// left. A base's own op that doesn't match is skipped, as X4 skips it, and noted.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import type { Document } from "@xmldom/xmldom";
import { applyDiff, parseXml } from "./patch.ts";

// Lines to print under the check's title: notes are fine, bad ones fail the check
export type Result = { notes: string[]; bad: string[] };

// Where a diff patches what's at its own path in the game: these folders, at any depth
const PATCHED_FOLDERS = ["aiscripts", "libraries", "md"];

const isDir = (path: string) => !!path && existsSync(path) && statSync(path).isDirectory();

// Every *.xml under dir, at any depth, sorted by path
const xmlFiles = (dir: string): string[] =>
  isDir(dir)
    ? readdirSync(dir, { recursive: true, encoding: "utf8" })
        .filter((name) => name.endsWith(".xml"))
        .map((name) => join(dir, name))
        .sort()
    : [];

// A layer of the game's files: a folder whose file at a path is the game's, a DLC's or SWI's
type Layer = { name: string; dir: string };

// The vanilla layers: the base game, then each DLC folder next to it, in name order
const vanillaLayers = (unpacked: string): Layer[] => [
  { name: "the game", dir: unpacked },
  ...readdirSync(dirname(unpacked))
    .filter((name) => name.startsWith("ego_dlc_") && isDir(join(dirname(unpacked), name)))
    .sort()
    .map((name) => ({ name, dir: join(dirname(unpacked), name) })),
];

// The XML X4 loads at rel after these layers, or null when none has a file there. Notes each
// layer diff op that doesn't match, as X4 skips it
const build = (rel: string, layers: Layer[], start: string | null, notes: string[]): string | null => {
  let text = start;
  for (const { name, dir } of layers) {
    const file = join(dir, rel);
    if (!existsSync(file)) continue;
    const layerText = readFileSync(file, "utf8");
    const layer = parseXml(layerText).documentElement!;
    // A full file counts only where no earlier layer has one (a DLC's or SWI's own script).
    // At a path the game has, X4 merges it (as the DLCs' icons.xml), which isn't modelled here
    if (layer.tagName !== "diff") {
      text ??= layerText;
      continue;
    }
    if (text === null) continue;
    const doc = parseXml(text);
    for (const r of applyDiff(doc, layer))
      if (r.count !== 1)
        notes.push(`${rel}: ${name}'s diff: <${r.op} sel="${r.sel}"> ${matches(r.count)}, skipped as X4 skips it`);
    text = doc.toString();
  }
  return text;
};

// SWI's layer for rel: ext02/ when it has the file (0.91 moved its scripts there, and a later
// catalog replaces an earlier one's whole file), else ext/ (0.90 has only ext/)
const swiLayer = (rel: string, swi: string): Layer[] =>
  ["ext02", "ext"]
    .map((d) => ({ name: "SWI", dir: join(swi, d) }))
    .filter(({ dir }) => existsSync(join(dir, rel)))
    .slice(0, 1);

const matches = (count: number | string) =>
  typeof count === "string" ? count : `matches ${count} node${count === 1 ? "" : "s"}`;

export const checkDiffPatches = (mod: string, unpacked: string, swi: string): Result => {
  const notes: string[] = [];
  const bad: string[] = [];
  if (!isDir(unpacked)) return { notes: ["not checked: X4_UNPACKED not found"], bad };
  const withSwi = isDir(swi);
  if (!withSwi) notes.push("8.00 + SWI not checked: SWI_UNPACKED not found");

  const files = PATCHED_FOLDERS.flatMap((folder) => xmlFiles(join(mod, folder)));
  for (const file of files) {
    const diff = parseXml(readFileSync(file, "utf8")).documentElement!;
    if (diff.tagName !== "diff") continue;
    const rel = relative(mod, file);
    const vanilla = build(rel, vanillaLayers(unpacked), null, notes);
    const bases: [string, string | null][] = [["vanilla 8.00", vanilla]];
    if (withSwi) bases.push(["8.00 + SWI", build(rel, swiLayer(rel, swi), vanilla, notes)]);
    for (const [base, text] of bases) {
      if (text === null) {
        bad.push(`${rel} on ${base}: no ${rel} to patch`);
        continue;
      }
      const doc: Document = parseXml(text);
      for (const r of applyDiff(doc, diff))
        (r.count === 1 ? notes : bad).push(`${rel} on ${base}: <${r.op} sel="${r.sel}"> ${matches(r.count)}`);
    }
  }
  return { notes, bad };
};

// An op of ours known not to match yet, with the issue that fixes it
export type Known = { file: string; sel: string; issue: string };

// Moves the bad lines of known mismatches to known (reported, but not failing the check). When
// both bases were checked (judgeStale), fails each known entry that no longer has a bad line, so
// the list doesn't outlive its issue
export const withKnown = ({ notes, bad }: Result, known: Known[], judgeStale = true): Result & { known: string[] } => {
  const entry = (line: string) => known.find((k) => line.startsWith(`${k.file} on `) && line.includes(` sel="${k.sel}">`));
  return {
    notes,
    known: bad.filter(entry).map((line) => `${entry(line)!.issue}: ${line}`),
    bad: [
      ...bad.filter((line) => !entry(line)),
      ...known
        .filter((k) => judgeStale && !bad.some((line) => entry(line) === k))
        .map((k) => `${k.file}: sel="${k.sel}" is listed as a known mismatch (${k.issue}) but matches on every base now: take it off the list`),
    ],
  };
};

const MATCHES_ONCE = / matches 1 node$/;

// The check's output: a title, then how many ops match (each one with verbose), the other notes,
// the known mismatches and the failures
export const report = ({ notes, known, bad }: Result & { known: string[] }, verbose = false): string[] => {
  const once = notes.filter((line) => MATCHES_ONCE.test(line));
  return [
    `Diff patches: ${bad.length ? "FAIL" : "ok"}`,
    ...(once.length ? [`  ${once.length} ops match exactly once`] : []),
    ...notes.filter((line) => verbose || !MATCHES_ONCE.test(line)).map((line) => `  ${line}`),
    ...known.map((line) => `  KNOWN ${line}`),
    ...bad.map((line) => `  FAIL ${line}`),
  ];
};
