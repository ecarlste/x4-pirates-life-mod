import { test } from "node:test";
import assert from "node:assert/strict";
import { missingPaths } from "./paths.ts";

// A repo with these files and folders; nothing is gitignored unless a test says so
const repo = (...paths: string[]) => ({
  exists: (path: string) => paths.includes(path),
  named: (name: string) => paths.some((path) => path.split("/").at(-1) === name),
  ignored: () => false,
});

test("a backticked repo path that doesn't exist is reported with its line", () => {
  const text = "Intro\nStubs live in `tests/lua/x4stubs.lua` now.\n";

  assert.deepEqual(missingPaths("docs/PROJECT.md", text, repo("tests/lua")), [
    { line: 2, path: "tests/lua/x4stubs.lua" },
  ]);
});

test("a relative link resolves from the doc's folder, without its anchor", () => {
  const text = "See [design](DESIGN.md#roadmap) and [gone](specs/booty.md#rules).\n";

  assert.deepEqual(missingPaths("docs/PROJECT.md", text, repo("docs/DESIGN.md")), [
    { line: 1, path: "docs/specs/booty.md" },
  ]);
});

test("backticked text is a path only with a slash or a known extension", () => {
  const text = "Run `make test`, raise `Bailed`, read `ghost.md` and `deploy.sh`, not `.feature` or `menu_map.lua`.\n";

  assert.deepEqual(missingPaths("README.md", text, repo("deploy.sh")), [{ line: 1, path: "ghost.md" }]);
});

test("a bare filename matches a file of that name anywhere in the repo", () => {
  const text = "Agreed design goes in `DESIGN.md`; booty in `booty.md`.\n";

  assert.deepEqual(missingPaths("docs/agents/domain.md", text, repo("docs/DESIGN.md")), [
    { line: 1, path: "booty.md" },
  ]);
});

test("a backticked path resolves from the repo root or the doc's folder", () => {
  const text = "`tools/check-deps.ts`, `check-deps/deps.ts`, `check-deps/gone.ts`\n";

  assert.deepEqual(missingPaths("tools/README.md", text, repo("tools/check-deps.ts", "tools/check-deps/deps.ts")), [
    { line: 1, path: "check-deps/gone.ts" },
  ]);
});

test("URLs, in-page anchors and absolute, home or Windows paths are skipped", () => {
  const text = [
    "[site](https://example.com/a.md) [mail](mailto:a@b.c) [here](#rules)",
    "`/mnt/e/x4-dev/reference/` `~/workspace/x4` `.\\tools\\unpack-x4.ps1` `E:\\SteamLibrary\\x.md`",
    "`https://github.com/a/b.md`",
  ].join("\n");

  assert.deepEqual(missingPaths("docs/PROJECT.md", text, repo()), []);
});

test("placeholders, elided paths and globs are skipped", () => {
  const text = "`tests/game/features/<feature>.feature` `…/md/x.xml` `.../ui.xml` `docs/…` `tools/**/*.test.ts` `*.md`\n";

  assert.deepEqual(missingPaths("docs/specs/_template.md", text, repo()), []);
});

test("paths .gitignore matches exist only after setup or a run, so are skipped", () => {
  const text = "`deploy.config` `.tools/bats-core` `.claude/worktrees/a` `tests/gone.sh`\n";
  const ignored = (path: string) => /^(deploy\.config|\.tools\/|\.claude\/worktrees\/)/.test(path);

  assert.deepEqual(missingPaths("docs/PROJECT.md", text, { ...repo(".claude"), ignored }), [
    { line: 1, path: "tests/gone.sh" },
  ]);
});

test("game-install paths are skipped unless they name one of our apirateslife files", () => {
  const text = [
    "`md/boarding.xml` `aiscripts/move.claim.xml` `ego_dlc_pirate/libraries/wares.xml` `base/md/notifications.xml`",
    "`extensions/apirateslife` `ui/addons/ego_gameoptions/gameoptions.lua` `subst02/ui/menu.xpl` `index/macros.xml`",
    "`md/apirateslife_booty.xml` `md/apirateslife_bail.xml`",
  ].join("\n");

  assert.deepEqual(missingPaths("docs/specs/capture-operation.md", text, repo("md/apirateslife_bail.xml")), [
    { line: 3, path: "md/apirateslife_booty.xml" },
  ]);
});

test("a line reference after a path is dropped before the path is checked", () => {
  const text = "`md/apirateslife_bail.xml:12` `tools/gone.ts:4-7,9`\n";

  assert.deepEqual(missingPaths("README.md", text, repo("md/apirateslife_bail.xml")), [
    { line: 1, path: "tools/gone.ts" },
  ]);
});

test("slashed names without an extension outside the repo's folders are refs, not paths", () => {
  const text = "`origin/main` `dorny/paths-filter` `spike/unlock-research-poc` `tests/lua/gone`\n";

  assert.deepEqual(missingPaths("tools/README.md", text, repo("tests")), [{ line: 1, path: "tests/lua/gone" }]);
});

test("fenced code blocks are skipped", () => {
  const text = "```bash\nnode `tools/gone.ts`\n```\n`tools/also-gone.ts`\n";

  assert.deepEqual(missingPaths("README.md", text, repo()), [{ line: 4, path: "tools/also-gone.ts" }]);
});

test("ticked checklist items record past work, so the files they name may be gone", () => {
  const text = "- [x] `tools/manual-checklist.py`, replaced\n- [ ] `tools/next-tool.ts`\n";

  assert.deepEqual(missingPaths("docs/IMPLEMENTATION_PLAN.md", text, repo()), [{ line: 2, path: "tools/next-tool.ts" }]);
});

test("planned docs not written yet are skipped", () => {
  const text = "Hooks are documented in `INTEGRATION.md`.\n";

  assert.deepEqual(missingPaths("docs/DESIGN.md", text, repo()), []);
});
