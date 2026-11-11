import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
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

test("a Windows path becomes its WSL path on Linux, as deploy.sh converts X4_PATH", () => {
  assert.equal(fromWindows("E:\\x4-dev\\reference\\x4-8.00\\base", "linux"), "/mnt/e/x4-dev/reference/x4-8.00/base");
  assert.equal(fromWindows("c:/Users/me", "linux"), "/mnt/c/Users/me");
  assert.equal(fromWindows("/already/wsl", "linux"), "/already/wsl");
  assert.equal(fromWindows("E:\\x", "win32"), "E:\\x");
});
