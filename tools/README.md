# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`run-game-tests.ps1`](run-game-tests.ps1) | Runs the in-game tests: installs the test extension, starts X4 through Steam (launch options must write `debuglog.txt`), follows `debuglog.txt` until the tests finish (or time out), removes the extension and writes a JUnit report to `tests/game/results.xml` and a Markdown report to `tests/game/report.md`. Deploy the mod first; `make game-test` does both. See [the research note](../docs/research/automated-game-testing.md) |
| [`post-game-test-report.sh`](post-game-test-report.sh) | Posts `tests/game/report.md` to the branch's PR as a comment and a `game-tests` commit status, after checking it's for the PR's latest commit with no uncommitted changes. Needs `gh`; `make game-test-report` runs it, `--dry-run` previews |
| [`check-test-plan.py`](check-test-plan.py) | Checks the game-test plan (`tests/game/features/*.feature`) against the game tests: every scenario's tag names a test (or `@pending` or `@manual`, counted separately), every test has a scenario, every spec links an existing feature file, steps use Gherkin keywords. `make test` runs it (`tests/test-plan.bats`) |
| [`check-test-plan-changes.py`](check-test-plan-changes.py) | PR check (`.github/workflows/test-plan.yml`): fails when a spec or the game tests changed against the base branch but the matching feature file didn't, unless the PR description (`PR_BODY`) says `Test plan: no change`. Tested in `tests/test-plan-changes.bats` |
| [`manual-checklist.py`](manual-checklist.py) | Writes the manual release checklist: every `@manual` scenario of the game-test plan as a Markdown checkbox with its steps, grouped by feature. Prints it, or writes it with `-o <file>`; `make release` will put it in `dist/` (`tests/manual-checklist.bats`) |
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

- Unpacked game data is reference only. It lives outside the repo and is never committed.
- Prerequisite: "X Tools" installed from the Steam library (provides `XRCatTool.exe`).
