// The debug-tags check's rule: no probe log tag (`[DEBUG-<id>]`, the tag
// /mattpocock-skills:diagnosing-bugs puts on every probe) is left in a file the mod ships or the
// game tests run. Cleanup after a diagnosis is a grep, so one missed probe would otherwise ship.

// The folders checked: the mod's scripts, libraries and texts, and the game tests' extensions
export const CHECKED_FOLDERS = ["aiscripts", "md", "libraries", "t", "tests/game"];

export type ProbeLine = { path: string; line: number; text: string };

const TAG = "[DEBUG-";

// Each line holding a probe tag, in the order given: its file, 1-based line number and trimmed text
export function probeLines(files: { path: string; text: string }[]): ProbeLine[] {
  return files.flatMap(({ path, text }) =>
    text.split(/\r?\n/).flatMap((line, i) => (line.includes(TAG) ? [{ path, line: i + 1, text: line.trim() }] : [])),
  );
}
