import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const cli = fileURLToPath(new URL("../check-doc-names.ts", import.meta.url));
const HARNESS = "tests/game/apirateslife_tests/md/apirateslife_tests.xml";
const RUNNER = "tools/run-game-tests.ps1";

const git = (cwd: string, ...args: string[]) =>
  spawnSync("git", ["-c", "user.name=T", "-c", "user.email=t@example.com", "-c", "core.hooksPath=/dev/null", ...args], {
    cwd,
    encoding: "utf8",
  });

const reports = (...names: string[]) => names.map((name) => `<signal_cue_instantly param="table[$name = '${name}']"/>`).join("\n");

// A git repo in a temp folder, with one commit per entry: the files it writes
function repo(...commits: Record<string, string>[]) {
  const root = mkdtempSync(join(tmpdir(), "doc-names-"));
  git(root, "init", "-q");
  for (const files of commits) {
    for (const [path, content] of Object.entries(files)) {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), content);
    }
    git(root, "add", "-A");
    git(root, "commit", "-q", "-m", "c");
  }
  return root;
}

const run = (cwd: string) => spawnSync(process.execPath, [cli], { cwd, encoding: "utf8" });

// The mod's script and the game tests, then a commit that retires old_bail_test
const history: Record<string, string>[] = [
  {
    "md/apirateslife_config.xml": `<set_value name="global.$APiratesLife_CaptureOps" exact="1"/>`,
    [HARNESS]: reports("old_bail_test", "claim_intact"),
    [RUNNER]: "New-LogCheck 'clean_log' $true 'ok'",
  },
  { [HARNESS]: reports("claim_intact") },
];

test("the CLI names each stale name by file and line and exits 1", () => {
  const root = repo(...history, {
    "docs/specs/x.md": "Sets `$APiratesLife_CaptureOps` and `$APiratesLife_Gone`.\nCovered by `old_bail_test`.\n",
    "tools/check.py": "# Tags name game tests (e.g. @old_bail_test, @claim_intact, @clean_log)\n",
    "docs/research/note.md": "`old_bail_test` once covered `$APiratesLife_Gone`.\n",
  });

  const result = run(join(root, "docs"));

  assert.equal(result.status, 1);
  assert.equal(
    result.stdout,
    [
      "Doc names: 3 stale",
      "  docs/specs/x.md:1: $APiratesLife_Gone isn't a mod global",
      "  docs/specs/x.md:2: old_bail_test is a retired game test",
      "  tools/check.py:1: old_bail_test is a retired game test",
      'Mark a name kept as history with "9.x line" or a link to the issue that removed it, on the same line.',
      "",
    ].join("\n"),
  );
});

test("the CLI says ok and exits 0 when every name exists", () => {
  const root = repo(...history, { "docs/specs/x.md": "`$APiratesLife_CaptureOps`, `claim_intact` and `clean_log`.\n" });

  const result = run(root);

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "Doc names: ok\n");
});

test("the CLI fails in a shallow clone, whose history can't show the retired names", () => {
  const root = repo(...history);
  const shallow = join(mkdtempSync(join(tmpdir(), "doc-names-shallow-")), "clone");
  git(root, "clone", "-q", "--depth", "1", `file://${root}`, shallow);

  const result = run(shallow);

  assert.equal(result.status, 1);
  assert.match(result.stderr, /shallow clone/);
});
