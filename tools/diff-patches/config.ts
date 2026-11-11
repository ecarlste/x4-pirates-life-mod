// A setting for the TypeScript tools, read as deploy.sh reads X4_PATH: the environment first, else
// the last line naming it in deploy.config (KEY="value", quotes optional), a Windows path
// converted to its WSL path. "" when it's set in neither.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

// E:\path -> /mnt/e/path on Linux (WSL); other paths, and every path elsewhere, unchanged
export const fromWindows = (path: string, platform: string = process.platform): string =>
  platform === "linux" && /^[A-Za-z]:[\\/]/.test(path)
    ? `/mnt/${path[0].toLowerCase()}/${path.slice(3).replace(/\\/g, "/")}`
    : path;

const unquote = (s: string) => s.replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");

export const configValue = (key: string, root: string, env: NodeJS.ProcessEnv = process.env): string => {
  let value = env[key] ?? "";
  const path = join(root, "deploy.config");
  if (!value && existsSync(path)) {
    for (const line of readFileSync(path, "utf8").split(/\r\n|\r|\n/)) {
      const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
      if (m && m[1] === key) value = unquote(m[2]);
    }
  }
  return fromWindows(value);
};
