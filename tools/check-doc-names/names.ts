// Finds the names a doc or tool names that the mod no longer has (tools/check-doc-names.ts): mod
// globals ($APiratesLife_…) the scripts don't mention, and game tests that were removed. Every rule
// for what is checked and what is kept as history is in the first section.
import { isCheckedDoc, TICKED } from "../check-doc-paths/paths.ts";

// What the mod has, as the CLI reads it from the scripts and the harness's and runner's history
export interface Known {
  // The mod globals the scripts in md/ and aiscripts/ mention, with their $
  globals: Set<string>;
  // The game tests the harness and runner reported at some commit but don't now
  retired: Set<string>;
}

export interface Stale {
  line: number;
  name: string;
  why: "isn't a mod global" | "is a retired game test";
}

// --- The rules ---

// The docs the doc-paths check reads, but the records (research notes, rejected ideas) and the 9.x
// line's design and plan, which name what was or will be; and the tools' code and docs, but their
// tests and fixtures, which make up names on purpose
const NOT_CHECKED_DOCS = /^docs\/(research|rejected)\/|^docs\/(DESIGN|IMPLEMENTATION_PLAN)\.md$/;
const NOT_CHECKED_TOOLS = /\.test\.ts$|\/fixtures\//;
export const isCheckedFile = (path: string) =>
  (isCheckedDoc(path) && !NOT_CHECKED_DOCS.test(path)) || (path.startsWith("tools/") && !NOT_CHECKED_TOOLS.test(path));

// A line that records history names what is gone on purpose: it says "9.x line", or links the issue
// that removed the name (#117, …/issues/117), or is a ticked checklist item (past work)
const HISTORY = [/9\.x line/i, /(^|[\s([])#\d+\b|\/issues\/\d+/, TICKED];

// Names agreed in a spec but not in the mod yet, outside the 9.x line's docs (none yet)
const PLANNED: string[] = [];

const GLOBAL = /\$APiratesLife_\w+/g;
// A game test is named backticked (`claim_intact`, `@claim_intact`) or as a scenario tag
// (@claim_intact); other snake_case (`set_owner`) is mostly the game's own
const TEST_NAME = /`@?([a-z0-9_]+)`|@([a-z0-9_]+)/g;
// A game test's name as the harness reports it ($name = '…') or the runner's log check (New-LogCheck '…')
const REPORTED_TEST = /\$name = '([a-z0-9_]+)'|New-LogCheck '([a-z0-9_]+)'/g;

// --- The check ---

// The mod globals a script mentions
export const modGlobals = (text: string) => [...text.matchAll(GLOBAL)].map(([name]) => name);

// The game tests the harness or runner text reports
export const gameTestNames = (text: string) =>
  [...text.matchAll(REPORTED_TEST)].map(([, harness, runner]) => harness ?? runner);

function lineStale(line: string, known: Known): Omit<Stale, "line">[] {
  const globals = modGlobals(line)
    .filter((name) => !known.globals.has(name) && !PLANNED.includes(name))
    .map((name) => ({ name, why: "isn't a mod global" as const }));
  const tests = [...line.matchAll(TEST_NAME)]
    .map(([, backticked, tagged]) => backticked ?? tagged)
    .filter((name) => known.retired.has(name))
    .map((name) => ({ name, why: "is a retired game test" as const }));
  return [...globals, ...tests];
}

export function staleNames(text: string, known: Known): Stale[] {
  return text
    .split("\n")
    .flatMap((line, i) =>
      HISTORY.some((rule) => rule.test(line)) ? [] : lineStale(line, known).map((stale) => ({ line: i + 1, ...stale })),
    );
}
