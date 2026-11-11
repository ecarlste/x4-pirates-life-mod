# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`run-game-tests.ps1`](run-game-tests.ps1) | Runs the in-game tests: installs the test extension, starts the X4 8.00 copy's `X4_nonsteam.exe` directly in its own test profile (`-personalfolderid`, `X4_PROFILE_ID` in `deploy.config`; `-PrepareProfile` makes it and switches SWI and our extensions on), follows that profile's `debuglog.txt` until the tests finish (or time out), removes the extension and writes a JUnit report to `tests/game/results.xml` and a Markdown report to `tests/game/report.md`. Deploy the mod first; `make game-test` does both. See [the research note](../docs/research/automated-game-testing.md) |
| [`post-game-test-report.sh`](post-game-test-report.sh) | Posts `tests/game/report.md` to the branch's PR as a comment and a `game-tests` commit status, after checking it's for the PR's latest commit with no uncommitted changes. Needs `gh`; `make game-test-report` runs it, `--dry-run` previews |
| [`check_test_plan.py`](check_test_plan.py) | Checks the test plan (`tests/game/features/*.feature`) against the game tests and unit tests: every scenario's tag names a test (or `@pending` or `@manual`, counted separately, never mixed), every game test has a scenario, unit test names (Lua in `tests/lua/`, Python in `tests/python/`) are unique, every spec links an existing feature file, steps use Gherkin keywords. `make test` runs it (`tests/test-plan.bats`) |
| [`test_plan_docs.py`](test_plan_docs.py) | Generates the readable test plan in `docs/test-plan/` (a page per feature file plus an index with coverage counts). `make test-plan` runs it; `--check` exits 1 naming stale pages (CI's test-plan check; `make test` only warns); `--checklist <file>` writes the release checklist, every `@manual` and `@pending` scenario with its steps (`-` prints it) (`tests/test-plan-docs.bats`) |
| [`select_tests.py`](select_tests.py) | Picks the test suites a change needs (since the branch left `origin/main`, uncommitted files included) by the path filters in `.github/test-filters.json`, the file CI's `dorny/paths-filter` step reads. `make test` uses it; `--all` picks everything, `--check` fails when a tracked file matches no filter or a test file has none, `--keys <json> --github` turns the action's matches into CI step outputs. Tested in `tests/python/test_select_tests.py` |
| [`check_test_plan_changes.py`](check_test_plan_changes.py) | PR check (`.github/workflows/test-plan.yml`): fails when a spec or the game tests changed against the base branch but the matching feature file didn't, unless the PR description (`PR_BODY`) says `Test plan: no change`. Tested in `tests/test-plan-changes.bats` |
| [`capture_metrics.py`](capture_metrics.py) | Turns the capture metrics summary lines (`[apirateslife] capture metrics: …`, one per capture attempt, from `md/apirateslife_metrics.xml`) in `debuglog.txt` files or folders of them into one CSV: `tools/capture_metrics.py -o captures.csv debuglog.txt`. See [the spec](../docs/specs/capture-metrics.md) (`tests/python/test_capture_metrics.py`) |
| [`worktree-status.sh`](worktree-status.sh) | Lists every worktree of the repo and flags work that could be lost: uncommitted changes, or commits on no remote whose changes haven't reached `origin/main` (checked by content, since squash merges leave branch commits behind, then by a merged PR via `gh`). Says which worktrees can be removed. `make worktrees` runs it; `--hook` is the SessionStart hook in `.claude/settings.json`, which warns at the start of every session (`tests/worktree-status.bats`) |
| [`check-diff-patches.ts`](check-diff-patches.ts) | The diff-patch check: applies each of our diff patches (`aiscripts/`, `md/`, `libraries/`) to the unpacked vanilla 8.00 file (the DLCs' diffs of it applied first) and to that with SWI's diff applied too, and fails when an op's `sel` matches anything but exactly one node. Real XPath, as X4 counts it; ops apply in order. Paths `X4_UNPACKED` and `SWI_UNPACKED` come from the environment or `deploy.config`; without them it skips with a note (as in CI). Mismatches with a fix ticketed are listed in its `KNOWN` list and reported as `KNOWN #<issue>` without failing; an entry fails once its op matches, so it's taken off. `--verbose` lists every op. `make test` runs it (`tools/diff-patches/*.test.ts`, on fixture XML) |
| [`check-deps.ts`](check-deps.ts) | Checks `node_modules` matches `package-lock.json`, naming any missing or stale package and saying to run `make setup`. `make test` runs it before the other TypeScript tools (`tools/check-deps/*.test.ts`) |
| [`unpack-x4.ps1`](unpack-x4.ps1) | Unpacks the base game and every DLC into `E:\x4-dev\reference\x4-<version>\` (one folder per DLC, `_subst` for base-file replacements) |

## Running

From PowerShell, in the repo folder:

```powershell
.\tools\unpack-x4.ps1 -Version 9.00
```

If scripts are blocked, run it for the current session only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\unpack-x4.ps1 -Version 9.00
```

From WSL:

```bash
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w tools/unpack-x4.ps1)" -Version 9.00
```

Run `Get-Help .\tools\unpack-x4.ps1 -Full` for every parameter (`-X4Path`, `-OutRoot`, `-ToolPath`, `-Force`).

## Rules

- New tools are TypeScript, run by Node directly (type stripping, no build step; Node 22.18 or later), with Node's built-in test runner: `tool.ts` with its modules and `*.test.ts` files in `tool/`. `make setup` runs `npm install`; `make test` runs `tsc` and the tests. A worktree uses the main checkout's `node_modules` unless its branch changes `package.json`. The existing Python tools stay Python.
- Python tools are named with underscores (`check_test_plan.py`), so their unit tests in `tests/python/` can import them; shell and PowerShell scripts use hyphens.

- Unpacked game data is reference only. It lives outside the repo and is never committed.
- Prerequisite: "X Tools" installed from the Steam library (provides `XRCatTool.exe`).
