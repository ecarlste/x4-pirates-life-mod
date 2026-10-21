# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`run-game-tests.ps1`](run-game-tests.ps1) | Runs the in-game tests: installs the test extension, starts X4 through Steam (launch options must write `debuglog.txt`), follows `debuglog.txt` until the tests finish (or time out), removes the extension and writes a JUnit report to `tests/game/results.xml` and a Markdown report to `tests/game/report.md`. Deploy the mod first; `make game-test` does both. See [the research note](../docs/research/automated-game-testing.md) |
| [`post-game-test-report.sh`](post-game-test-report.sh) | Posts `tests/game/report.md` to the branch's PR as a comment and a `game-tests` commit status, after checking it's for the PR's latest commit with no uncommitted changes. Needs `gh`; `make game-test-report` runs it, `--dry-run` previews |
| [`check-test-plan.py`](check-test-plan.py) | Checks the game-test plan (`tests/game/features/*.feature`) against the game tests: every scenario's tag names a test (or `@pending`), every test has a scenario, steps use Gherkin keywords. `make test` runs it (`tests/test-plan.bats`) |
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
