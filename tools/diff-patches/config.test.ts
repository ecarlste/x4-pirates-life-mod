import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { configValue, fromWindows } from "./config.ts";

const repo = (config?: string) => {
  const root = mkdtempSync(join(tmpdir(), "diff-patches-config-"));
  if (config !== undefined) writeFileSync(join(root, "deploy.config"), config);
  return root;
};

test("a value comes from the last line naming it in deploy.config, without quotes or spaces", () => {
  const root = repo(`# X4_UNPACKED="ignored"\nX4_UNPACKED = "/first"\r\n  X4_UNPACKED='/data/x4' \nOTHER=1\n`);
  assert.equal(configValue("X4_UNPACKED", root, {}), "/data/x4");
});

test("the environment wins over deploy.config", () => {
  const root = repo(`X4_UNPACKED="/from/file"\n`);
  assert.equal(configValue("X4_UNPACKED", root, { X4_UNPACKED: "/from/env" }), "/from/env");
});

test("a value set nowhere, or with no deploy.config, is empty", () => {
  assert.equal(configValue("SWI_UNPACKED", repo(`X4_UNPACKED="/x"\n`), {}), "");
  assert.equal(configValue("SWI_UNPACKED", repo(), {}), "");
});

// A main checkout with a linked worktree, laid out as git worktree add makes them: the worktree's
// .git file points at .git/worktrees/<name>, whose commondir leads back to the main .git
const checkouts = (mainConfig?: string, worktreeConfig?: string) => {
  const main = repo(mainConfig);
  const gitdir = join(main, ".git", "worktrees", "wt");
  mkdirSync(gitdir, { recursive: true });
  writeFileSync(join(gitdir, "commondir"), "../..\n");
  const worktree = join(main, ".claude", "worktrees", "wt");
  mkdirSync(worktree, { recursive: true });
  writeFileSync(join(worktree, ".git"), `gitdir: ${gitdir}\n`);
  if (worktreeConfig !== undefined) writeFileSync(join(worktree, "deploy.config"), worktreeConfig);
  return { main, worktree };
};

test("a worktree without the setting reads the main checkout's deploy.config", () => {
  const { worktree } = checkouts(`X4_UNPACKED="/from/main"\n`);
  assert.equal(configValue("X4_UNPACKED", worktree, {}), "/from/main");
});

test("a worktree's own deploy.config wins over the main checkout's, setting by setting", () => {
  const { worktree } = checkouts(`X4_UNPACKED="/from/main"\nSWI_UNPACKED="/swi/main"\n`, `X4_UNPACKED="/from/worktree"\n`);
  assert.equal(configValue("X4_UNPACKED", worktree, {}), "/from/worktree");
  assert.equal(configValue("SWI_UNPACKED", worktree, {}), "/swi/main");
});

test("the environment wins over both checkouts' deploy.config", () => {
  const { worktree } = checkouts(`X4_UNPACKED="/from/main"\n`, `X4_UNPACKED="/from/worktree"\n`);
  assert.equal(configValue("X4_UNPACKED", worktree, { X4_UNPACKED: "/from/env" }), "/from/env");
});

test("a Windows path becomes its WSL path on Linux, as deploy.sh converts X4_PATH", () => {
  assert.equal(fromWindows("E:\\x4-dev\\reference\\x4-8.00\\base", "linux"), "/mnt/e/x4-dev/reference/x4-8.00/base");
  assert.equal(fromWindows("c:/Users/me", "linux"), "/mnt/c/Users/me");
  assert.equal(fromWindows("/already/wsl", "linux"), "/already/wsl");
  assert.equal(fromWindows("E:\\x", "win32"), "E:\\x");
});
