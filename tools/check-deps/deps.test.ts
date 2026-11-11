import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checkDeps } from "./deps.ts";

const writeJson = (path: string, value: unknown) => {
  mkdirSync(join(path, ".."), { recursive: true });
  writeFileSync(path, JSON.stringify(value));
};

// A repo root with package.json and package-lock.json for saxes 6.0.0 and @xmldom/xmldom 0.9.12
function fakeRepo(): string {
  const root = mkdtempSync(join(tmpdir(), "check-deps-"));
  writeJson(join(root, "package.json"), {
    devDependencies: { "@xmldom/xmldom": "0.9.12", saxes: "6.0.0" },
  });
  writeJson(join(root, "package-lock.json"), {
    lockfileVersion: 3,
    packages: {
      "": { devDependencies: { "@xmldom/xmldom": "0.9.12", saxes: "6.0.0" } },
      "node_modules/@xmldom/xmldom": { version: "0.9.12" },
      "node_modules/saxes": { version: "6.0.0" },
    },
  });
  mkdirSync(join(root, "tools"));
  return root;
}

const install = (dir: string, name: string, version: string) =>
  writeJson(join(dir, "node_modules", name, "package.json"), { name, version });

test("in sync: no problems", () => {
  const root = fakeRepo();
  install(root, "@xmldom/xmldom", "0.9.12");
  install(root, "saxes", "6.0.0");

  assert.deepEqual(checkDeps(root, join(root, "tools")), []);
});

test("a missing package is named", () => {
  const root = fakeRepo();
  install(root, "@xmldom/xmldom", "0.9.12");

  assert.deepEqual(checkDeps(root, join(root, "tools")), [
    "saxes: not installed (package-lock.json has 6.0.0)",
  ]);
});

test("a version that differs from the lock is named", () => {
  const root = fakeRepo();
  install(root, "@xmldom/xmldom", "0.9.11");
  install(root, "saxes", "6.0.0");

  assert.deepEqual(checkDeps(root, join(root, "tools")), [
    "@xmldom/xmldom: installed 0.9.11, package-lock.json has 0.9.12",
  ]);
});

test("a worktree with no node_modules of its own uses the main checkout's", () => {
  const main = fakeRepo();
  install(main, "@xmldom/xmldom", "0.9.12");
  install(main, "saxes", "6.0.0");
  const worktree = join(main, ".claude", "worktrees", "issue-1");
  writeJson(join(worktree, "package.json"), {
    devDependencies: { "@xmldom/xmldom": "0.9.12", saxes: "6.0.0", xpath: "0.0.36" },
  });
  writeJson(join(worktree, "package-lock.json"), {
    lockfileVersion: 3,
    packages: {
      "node_modules/@xmldom/xmldom": { version: "0.9.12" },
      "node_modules/saxes": { version: "6.0.0" },
      "node_modules/xpath": { version: "0.0.36" },
    },
  });

  assert.deepEqual(checkDeps(worktree, join(worktree, "tools")), [
    "xpath: not installed (package-lock.json has 0.0.36)",
  ]);
});
