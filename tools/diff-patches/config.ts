// A setting for the TypeScript tools, read as deploy.sh reads X4_PATH: the environment first, else
// the last line naming it in the checkout's deploy.config, else in the main checkout's (for a
// worktree; KEY="value", quotes optional), a Windows path converted to its WSL path. "" when it's
// set in none of them.
import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

// E:\path -> /mnt/e/path on Linux (WSL); other paths, and every path elsewhere, unchanged
export const fromWindows = (path: string, platform: string = process.platform): string =>
  platform === "linux" && /^[A-Za-z]:[\\/]/.test(path)
    ? `/mnt/${path[0].toLowerCase()}/${path.slice(3).replace(/\\/g, "/")}`
    : path;

const unquote = (s: string) => s.replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");

// The main checkout of a linked worktree, from its .git file (gitdir: <main>/.git/worktrees/<name>)
// and that folder's commondir (../..); "" for a main checkout, or anything else
export const mainCheckout = (root: string): string => {
  const dotGit = join(root, ".git");
  if (!existsSync(dotGit) || !statSync(dotGit).isFile()) return "";
  const m = /^gitdir:\s*(.+?)\s*$/m.exec(readFileSync(dotGit, "utf8"));
  if (!m) return "";
  const gitdir = resolve(root, m[1]);
  const commondirFile = join(gitdir, "commondir");
  const common = existsSync(commondirFile) ? resolve(gitdir, readFileSync(commondirFile, "utf8").trim()) : gitdir;
  return basename(common) === ".git" ? dirname(common) : "";
};

// The last value a deploy.config gives the key, or undefined
const fileValue = (path: string, key: string): string | undefined => {
  if (!existsSync(path)) return undefined;
  let value: string | undefined;
  for (const line of readFileSync(path, "utf8").split(/\r\n|\r|\n/)) {
    const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
    if (m && m[1] === key) value = unquote(m[2]);
  }
  return value;
};

export const configValue = (key: string, root: string, env: NodeJS.ProcessEnv = process.env): string => {
  let value = env[key] ?? "";
  const main = mainCheckout(root);
  for (const dir of main ? [root, main] : [root]) {
    if (value) break;
    value = fileValue(join(dir, "deploy.config"), key) ?? "";
  }
  return fromWindows(value);
};
