# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`run-game-tests.ps1`](run-game-tests.ps1) | Runs the in-game tests: installs the test extension, starts X4 through Steam (launch options must write `debuglog.txt`), follows `debuglog.txt` until the tests finish (or time out), removes the extension and writes a JUnit report to `tests/game/results.xml` and a Markdown report to `tests/game/report.md`. Deploy the mod first; `make game-test` does both. `-Tests` runs only the named tests; `-NoneNeeded` writes a "none needed" report without starting the game. See [the research note](../docs/research/automated-game-testing.md) |
| [`post-game-test-report.sh`](post-game-test-report.sh) | Posts `tests/game/report.md` to the branch's PR as a comment and a `game-tests` commit status, after checking it's for the PR's latest commit with no uncommitted changes. Needs `gh`; `make game-test-report` runs it, `--dry-run` previews |
| [`check_test_plan.py`](check_test_plan.py) | Checks the test plan (`tests/game/features/*.feature`) against the game tests and unit tests: every scenario's tag names a test (or `@pending` or `@manual`, counted separately, never mixed), every game test has a scenario, unit test names (Lua in `tests/lua/`, Python in `tests/python/`) are unique, every spec links an existing feature file, steps use Gherkin keywords. `make test` runs it (`tests/test-plan.bats`) |
| [`test_plan_docs.py`](test_plan_docs.py) | Generates the readable test plan in `docs/test-plan/` (a page per feature file plus an index with coverage counts). `make test-plan` runs it; `--check` exits 1 naming stale pages (CI's test-plan check; `make test` only warns); `--checklist <file>` writes the release checklist, every `@manual` and `@pending` scenario with its steps (`-` prints it) (`tests/test-plan-docs.bats`) |
| [`select_tests.py`](select_tests.py) | Picks the test suites a change needs (since the branch left `origin/main`, uncommitted files included) by the path filters in `.github/test-filters.json`, the file CI's `dorny/paths-filter` step reads. `make test` uses it; `--all` picks everything, `--check` fails when a tracked file matches no filter or a test file has none, `--keys <json> --github` turns the action's matches into CI step outputs. `--game` picks game tests by the `game:` filters, for `make game-test`. Tested in `tests/python/test_select_tests.py` |
| [`check_test_plan_changes.py`](check_test_plan_changes.py) | PR check (`.github/workflows/test-plan.yml`): fails when a spec or the game tests changed against the base branch but the matching feature file didn't, unless the PR description (`PR_BODY`) says `Test plan: no change`. Tested in `tests/test-plan-changes.bats` |
| [`capture_metrics.py`](capture_metrics.py) | Turns the capture metrics summary lines (`[apirateslife] capture metrics: …`, one per capture attempt, from `md/apirateslife_metrics.xml`) in `debuglog.txt` files or folders of them into one CSV: `tools/capture_metrics.py -o captures.csv debuglog.txt`. See [the spec](../docs/specs/capture-metrics.md) (`tests/python/test_capture_metrics.py`) |
| [`generate_variants.py`](generate_variants.py) | Writes the pirate variants listed in `profiles/vanilla/variants.xml` into the mod from the unpacked game files: rigged copies of the vanilla ship macros (and their storage macros) and of engines, shields, weapons and turrets (with their bullets, and a turret's destructible twin) and missiles (with their effect lists, `libraries/influenceconfigurations.xml`), with marks beyond the base game's built up by a step rig, `index/macros.xml`, the variant and unlock-research wares in `libraries/wares.xml`, the generated text page in `t/0001-l044.xml`, and `md/apirateslife_variants_vanilla.xml`, the library listing each variant's unlock and level for the booty script. It also writes `profiles/vanilla/variants.manifest`: a stamp of the list and the script, and a hash of each file it writes, so a run changes only files whose content changed. `make variants` runs it (`--reference DIR` or `$X4_REFERENCE` for the unpacked install); `--check` compares instead, in full with the game files (then by the manifest too) and by the manifest alone without them, which is how `make test` and CI run it. See [the spec](../docs/specs/booty.md#variants) (`tests/python/test_generate_variants.py`) |
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

- Python tools are named with underscores (`check_test_plan.py`), so their unit tests in `tests/python/` can import them; shell and PowerShell scripts use hyphens.

- Unpacked game data is reference only. It lives outside the repo and is never committed.
- Prerequisite: "X Tools" installed from the Steam library (provides `XRCatTool.exe`).
