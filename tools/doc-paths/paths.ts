// Finds the repo paths a Markdown doc names that don't exist (tools/check-doc-paths.ts): relative
// link targets, and backticked text that looks like a path. What's skipped on purpose is in SKIP.
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

// Backticked text without a slash is a path only when it's a name ending in one of these (not
// .xml or .lua: bare names of those are mostly the game's files)
const BARE_NAME = /^[^.].*\.(md|ts|py|sh|ps1|bats|json|feature|ya?ml)$/;

// Docs agreed but not written yet
const PLANNED = ["INTEGRATION.md"];

// Text that names something other than a repo path, all in one place. Files that exist only after
// setup or a run (deploy.config, .tools/) are skipped too, by .gitignore (Repo.ignored).
const SKIP = [
  /^[a-z][a-z0-9+.-]*:/i, // URLs (https:, mailto:) and Windows drives (E:)
  /^[/~]/, // absolute and home paths
  /\\/, // Windows paths
  /[<>*]/, // placeholders (<name>) and globs (*, **)
  /…|\.\.\./, // elided paths (…/md/x.xml, docs/…)
];
// The game install's folders (vanilla files, the DLCs', extensions): our own files in them are all
// named apirateslife*, so only those are checked
const GAME_FOLDERS = /^(md|aiscripts|libraries|ui|index|t|voice|assets|maps|extensions|base|ego_dlc_[^/]*|subst[^/]*)\//;
const skipped = (path: string) =>
  SKIP.some((rule) => rule.test(path)) || (GAME_FOLDERS.test(path) && !posix.basename(path).includes("apirateslife"));

// Removes fenced code blocks (keeping their lines, so line numbers stay right)
const withoutFences = (text: string) =>
  text.replace(/^(```|~~~).*\n[\s\S]*?^\1.*$/gm, (block) => block.replace(/[^\n]/g, ""));

export function missingPaths(doc: string, text: string, repo: Repo): Missing[] {
  const missing: Missing[] = [];
  const folder = posix.dirname(doc);
  // A path is fine when one of its readings exists or is gitignored
  const found = (...paths: string[]) => paths.some((path) => repo.exists(path)) || paths.some((path) => repo.ignored(path));

  withoutFences(text)
    .split("\n")
    .forEach((content, i) => {
      // A ticked checklist item records past work, so the files it names may be gone
      if (/^\s*[-*] \[x\]/i.test(content)) return;
      const report = (path: string) => missing.push({ line: i + 1, path });
      for (const [, target] of content.matchAll(/\]\(([^)\s]+)\)/g)) {
        if (target.startsWith("#") || skipped(target)) continue;
        const path = posix.join(folder, target.replace(/#.*/, ""));
        if (!found(path)) report(path);
      }
      for (const [, code] of content.matchAll(/`([^`]+)`/g)) {
        const token = code.replace(/:[\d,-]+$/, ""); // a line reference (x.xml:12-14)
        if (/\s/.test(token) || skipped(token)) continue;
        if (token.includes("/")) {
          // A slashed name with no extension outside the repo's folders is a ref (origin/main), not a path
          const hasExtension = /\.\w+$/.test(posix.basename(token));
          if (!hasExtension && !repo.exists(token.split("/")[0])) continue;
          // From the repo root, as most docs write paths, or from the doc's folder
          if (!found(posix.normalize(token), posix.join(folder, token))) report(token);
        } else if (BARE_NAME.test(token) && !PLANNED.includes(token) && !repo.named(token)) {
          report(token);
        }
      }
    });
  return missing;
}
