# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`run-game-tests.ps1`](run-game-tests.ps1) | Runs the in-game tests: installs the test extension, starts the X4 8.00 copy's `X4_nonsteam.exe` directly in its own test profile (`-personalfolderid`, `X4_PROFILE_ID` in `deploy.config`; `-PrepareProfile` makes it and switches SWI and our extensions on), follows that profile's `debuglog.txt` until the tests finish (or time out), removes the extension and writes a JUnit report to `tests/game/results.xml` and a Markdown report to `tests/game/report.md`. Deploy the mod first; `make game-test` does both. See [the research note](../docs/research/automated-game-testing.md) |
| [`game-lock.sh`](game-lock.sh), [`game-lock.ps1`](game-lock.ps1) | The machine-wide [game lock](#the-game-lock): one deploy or game run at a time, in this repo and the bounty hunter's. `deploy.sh` and `deploy.ps1` take it while they change the game folder, `run-game-tests.ps1` for its whole run, and `make game-test` around both its deploy and its run (`tools/game-lock.sh --what game-test -- <command>`), handing it down to them (`tests/deploy.bats`, `tests/makefile.bats`, `tests/DeployLock.Tests.ps1`, `tests/RunGameTestsLock.Tests.ps1`) |
| [`post-game-test-report.sh`](post-game-test-report.sh) | Posts `tests/game/report.md` to the branch's PR as a comment and a `game-tests` commit status, after checking it's for the PR's latest commit with no uncommitted changes. Needs `gh`; `make game-test-report` runs it, `--dry-run` previews |
| [`check_test_plan.py`](check_test_plan.py) | Checks the test plan (`tests/game/features/*.feature`) against the game tests and unit tests: every scenario's tag names a test (or `@pending` or `@manual`, counted separately, never mixed), every game test has a scenario, unit test names (Lua in `tests/lua/`, Python in `tests/python/`) are unique, every spec links an existing feature file, steps use Gherkin keywords. `make test` runs it (`tests/test-plan.bats`) |
| [`test_plan_docs.py`](test_plan_docs.py) | Generates the readable test plan in `docs/test-plan/` (a page per feature file plus an index with coverage counts). `make test-plan` runs it; `--check` exits 1 naming stale pages (CI's test-plan check; `make test` only warns); `--checklist <file>` writes the release checklist, every `@manual` and `@pending` scenario with its steps (`-` prints it) (`tests/test-plan-docs.bats`) |
| [`select_tests.py`](select_tests.py) | Picks the test suites a change needs (since the branch left `origin/main`, uncommitted files included) by the path filters in `.github/test-filters.json`, the file CI's `dorny/paths-filter` step reads. `make test` uses it; `--all` picks everything, `--check` fails when a tracked file matches no filter or a test file has none, `--keys <json> --github` turns the action's matches into CI step outputs. The suites with a CI job of their own (`OWN_JOB_SUITES`: `lua`, `typescript`, `doc-paths`) each get a `<name>=true/false` output and stay out of `suites=`, the bats job's list; adding a suite to that list moves it out of the bats job, so its own job in `.github/workflows/tests.yml` (and the `changes` job's output for it) must exist too. Tested in `tests/python/test_select_tests.py` |
| [`check_test_plan_changes.py`](check_test_plan_changes.py) | PR check (`.github/workflows/test-plan.yml`): fails when a spec or the game tests changed against the base branch but the matching feature file didn't, unless the PR description (`PR_BODY`) says `Test plan: no change`. Tested in `tests/test-plan-changes.bats` |
| [`capture_metrics.py`](capture_metrics.py) | Turns the capture metrics summary lines (`[apirateslife] capture metrics: …`, one per capture attempt, from `md/apirateslife_metrics.xml`) in `debuglog.txt` files or folders of them into one CSV: `tools/capture_metrics.py -o captures.csv debuglog.txt`. See [the spec](../docs/specs/capture-metrics.md) (`tests/python/test_capture_metrics.py`) |
| [`worktree-status.sh`](worktree-status.sh) | Lists every worktree of the repo and flags work that could be lost: uncommitted changes, or commits on no remote whose changes haven't reached `origin/main` (checked by content, since squash merges leave branch commits behind, then by a merged PR via `gh`). Says which worktrees can be removed. `make worktrees` runs it; `--hook` is the SessionStart hook in `.claude/settings.json`, which warns at the start of every session (`tests/worktree-status.bats`) |
| [`check-diff-patches.ts`](check-diff-patches.ts) | The diff-patch check: applies each of our diff patches (`aiscripts/`, `md/`, `libraries/`) to the unpacked vanilla 8.00 file (the DLCs' diffs of it applied first) and to that with SWI's diff applied too, and fails when an op's `sel` matches anything but exactly one node. Real XPath, as X4 counts it; ops apply in order. Paths `X4_UNPACKED` and `SWI_UNPACKED` come from the environment or `deploy.config` (read as `deploy.sh` reads it, `tools/diff-patches/config.ts`); without them it skips with a note (as in CI). Mismatches with a fix ticketed are listed in its `KNOWN` list and reported as `KNOWN #<issue>` without failing; an entry fails once its op matches, so it's taken off. `--verbose` lists every op. `make test` runs it (`tools/diff-patches/*.test.ts`, on fixture XML) |
| [`check-doc-paths.ts`](check-doc-paths.ts) | Fails when a doc names a repo path that doesn't exist, as when files leave the repo but the docs still name them. Checks `docs/**/*.md` (not the generated `docs/test-plan/`), `README.md`, `tools/README.md`, `GLOSSARY.md` and `CLAUDE.md`: relative link targets, and backticked text with a slash or ending in a known extension (a bare name matches a file of that name anywhere). Skips URLs, absolute and Windows paths, placeholders, globs, elided paths, git refs, gitignored files (made by setup or a run), the game install's files (in `md/`, `ego_dlc_*/`, … only `apirateslife*` names are ours), code blocks, the backticks of ticked checklist items, and planned docs; the rules are in one place, the top of `tools/check-doc-paths/paths.ts`. `make doc-paths` runs it; `make test` and CI on every change, since a file leaving can break a doc it doesn't touch (`tools/check-doc-paths/*.test.ts`) |
| [`check-deps.ts`](check-deps.ts) | Checks `node_modules` matches `package-lock.json`, naming any missing or stale package and saying to run `make setup`. `make test` runs it before the other TypeScript tools (`tools/check-deps/*.test.ts`) |
| [`standards.test.ts`](standards.test.ts) | Checks the mechanical rules listed under [Rules](#rules), each tested on a planted breach in a temp folder, and fails with a line naming the file and the rule. `make test` runs it with the TypeScript tests |
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

## The game lock

X4 runs one game per Windows login, and this repo and the bounty hunter's share the X4 8.00 copy, so a deploy or game run from either waits for any other. Any tool that changes the game folder or starts the game should take the lock the same way:

- **Where:** the file `game.lock` in the X4 install folder (`<X4_PATH>\game.lock`), the folder both repos' configs name.
- **Format:** UTF-8 text, one `key=value` per line, LF endings:

  ```
  token=<unique per holder>
  what=deploy | game-test | <the tool's own word>
  repo=<repo folder name>
  branch=<branch, or ->
  pid=<holder's process id>
  host=wsl | windows | linux
  started=<UTC, 2026-11-11T09:00:00Z>
  heartbeat=<counter> <UTC time>
  ```

  Only `token` and the rule that the file keeps changing matter to the protocol; the rest is for the waiting message.
- **Taking it:** create the file exclusively (fail if it exists: `CreateNew` in .NET, `set -o noclobber` in bash), then write the lines. If it exists, someone holds it: wait, polling every few seconds, and say who holds it.
- **Holding it:** rewrite the file (bump the `heartbeat` line) at least every 10 s, and stop if its `token` is no longer yours.
- **A crashed holder:** a lock whose text hasn't changed for 60 s, as watched by the waiter on its own clock (so the two clocks never need to agree), is taken over: delete it and take it as above.
- **Letting go:** delete the file, but only if its `token` is still yours.
- **Handing it down:** a holder that starts another tool which takes the lock passes its token in `X4_GAME_LOCK_TOKEN` (from WSL to a Windows program, list it in `WSLENV` too). A tool whose `X4_GAME_LOCK_TOKEN` matches the file's `token` goes ahead without waiting, and leaves the file for the holder to delete.
- **Settings** (environment only): `X4_GAME_LOCK_WAIT`, seconds to wait (default 1800; 0 refuses at once with the holder's name), `X4_GAME_LOCK_STALE` (default 60) and `X4_GAME_LOCK_POLL` (default 5).

Limits:

- **It's per install, not per machine.** It serializes everything that names the same `X4_PATH`, which today is every deploy and game run in both repos (the 8.00 copy). A tool pointed at another install (the 9.00 Steam copy, say) takes a different lock; X4's own one-game-per-login rule and the runner's process check stop the second game from starting, but not the deploy into it.
- It doesn't cover a game started by hand (the runner refuses while `X4` or `X4_nonsteam` runs).
- `X4_GAME_LOCK_STALE` must be the same in both repos: a holder beats every STALE/6 s, so a waiter with a smaller value could take over a live lock.
- Two waiters taking over the same crashed lock at the same moment could both think they hold it; each checks the text is unchanged right before deleting it, which makes that window tiny, and at our scale the rest is left to chance.

## Rules

- New tools are TypeScript, run by Node directly (type stripping, no build step; Node 22.18 or later), with Node's built-in test runner: `<tool>.ts` with its modules and `*.test.ts` files in `<tool>/`. `make setup` runs `npm install`; `make test` runs `tsc` and the tests. A worktree uses the main checkout's `node_modules` unless its branch changes `package.json`. The existing Python tools stay Python.
- `tools/standards.test.ts` checks the mechanical rules: only CLIs (`.ts` files using `parseArgs`) sit directly in `tools/`, any other module or test goes in its tool's folder (except `standards.test.ts` itself, which checks `tools/` as a whole); every file directly in `tools/` has a row in the table above, and every row names a file that exists; CLIs read arguments with `parseArgs`, never `process.argv`, and exit 2 with a `Usage:` line on stderr for an unknown option; devDependencies use `^` ranges (`package-lock.json` pins).
- Python tools are named with underscores (`check_test_plan.py`), so their unit tests in `tests/python/` can import them; shell and PowerShell scripts use hyphens.

- Unpacked game data is reference only. It lives outside the repo and is never committed.
- Prerequisite: "X Tools" installed from the Steam library (provides `XRCatTool.exe`).
