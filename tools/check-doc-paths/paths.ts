// Finds the repo paths a Markdown doc names that don't exist (tools/check-doc-paths.ts): relative
// link targets, and backticked text that looks like a path. Every rule for what is checked and
// what is skipped on purpose is in the first section; add one only for text that isn't a repo path.
import { posix } from "node:path";

export interface Missing {
  line: number;
  path: string;
}

export interface Repo {
  // Whether the path, relative to the repo root, is a file or folder
  exists: (path: string) => boolean;
  // Whether any file in the repo has this name
  named: (name: string) => boolean;
  // Whether .gitignore matches it: files that exist only after setup or a run (deploy.config, .tools/)
  ignored: (path: string) => boolean;
}

// --- The rules ---

// The docs checked: docs/**/*.md but the generated test plan, and the top-level docs
const TOP_LEVEL_DOCS = ["README.md", "tools/README.md", "GLOSSARY.md", "CLAUDE.md"];
export const isCheckedDoc = (path: string) =>
  (/^docs\/.*\.md$/.test(path) && !path.startsWith("docs/test-plan/")) || TOP_LEVEL_DOCS.includes(path);

// Backticked text without a slash is a path only when it's a name ending in one of these (not
// .xml or .lua: bare names of those are mostly the game's files)
const BARE_NAME = /^[^.].*\.(md|ts|py|sh|ps1|bats|json|feature|ya?ml)$/;

// Text that names something other than a repo path
const NOT_A_PATH = [
  /^[a-z][a-z0-9+.-]*:/i, // URLs (https:, mailto:) and Windows drives (E:)
  /^[/~]/, // absolute and home paths
  /\\/, // Windows paths
  /[<>*]/, // placeholders (<name>) and globs (*, **)
  /…|\.\.\./, // elided paths (…/md/x.xml, docs/…)
];

// The game install's folders (vanilla files, the DLCs', extensions): our own files in them are all
// named apirateslife*, so only those are checked
const GAME_FOLDERS = /^(md|aiscripts|libraries|ui|index|t|voice|assets|maps|extensions|base|ego_dlc_[^/]*|subst[^/]*)\//;

// Paths agreed in the plan but not made yet: a doc, the release folder
const PLANNED = ["INTEGRATION.md", "dist/"];

// A ticked checklist item records past work, so the files its backticks name may be gone (its links
// are still checked)
export const TICKED = /^\s*[-*] \[x\]/i;

// A slashed name with no extension or trailing slash, outside the repo's folders, is a ref
// (origin/main, dorny/paths-filter), not a path
const isRef = (token: string, repo: Repo) => !/(\.\w+|\/)$/.test(token) && !repo.exists(token.split("/")[0]);

const isSkipped = (path: string) =>
  NOT_A_PATH.some((rule) => rule.test(path)) || (GAME_FOLDERS.test(path) && !posix.basename(path).includes("apirateslife"));

// Removes fenced code blocks (keeping their lines, so line numbers stay right): commands, not prose
const withoutFences = (text: string) =>
  text.replace(/^(```|~~~).*\n[\s\S]*?^\1.*$/gm, (block) => block.replace(/[^\n]/g, ""));

// --- The check ---

// A path a doc names, as it's written, and the repo paths it may mean; none when it can't be found
interface Named {
  path: string;
  readings: string[];
}

// The relative link targets on a line, resolved from the doc's folder, without anchors
function linkPaths(line: string, folder: string): Named[] {
  return [...line.matchAll(/\]\(([^)\s]+)\)/g)]
    .map(([, target]) => target)
    .filter((target) => !target.startsWith("#") && !isSkipped(target))
    .map((target) => {
      const path = posix.join(folder, target.replace(/#.*/, ""));
      return { path, readings: [path] };
    });
}

// The backticked paths on a line: from the repo root, as most docs write them, or from the doc's
// folder. A bare name can be anywhere, so it's found when any file has its name.
function codePaths(line: string, folder: string, repo: Repo): Named[] {
  if (TICKED.test(line)) return [];
  return [...line.matchAll(/`([^`]+)`/g)]
    .map(([, code]) => code.replace(/:[\d,-]+$/, "")) // a line reference (x.xml:12-14)
    .filter((token) => !/\s/.test(token) && !isSkipped(token) && !PLANNED.includes(token))
    .flatMap((path) => {
      if (path.includes("/")) return isRef(path, repo) ? [] : [{ path, readings: [posix.normalize(path), posix.join(folder, path)] }];
      return BARE_NAME.test(path) && !repo.named(path) ? [{ path, readings: [] }] : [];
    });
}

export function missingPaths(doc: string, text: string, repo: Repo): Missing[] {
  const folder = posix.dirname(doc);
  const isFound = ({ readings }: Named) => readings.some((path) => repo.exists(path) || repo.ignored(path));

  return withoutFences(text)
    .split("\n")
    .flatMap((line, i) =>
      [...linkPaths(line, folder), ...codePaths(line, folder, repo)]
        .filter((named) => !isFound(named))
        .map(({ path }) => ({ line: i + 1, path })),
    );
}
