# Testing

How to run, add and wire up tests. The scripts say how they fetch and pin their tools: [`tests/run.sh`](../tests/run.sh), [`tests/run.ps1`](../tests/run.ps1), [`.github/test-filters.json`](../.github/test-filters.json), [`.github/workflows/tests.yml`](../.github/workflows/tests.yml) and [`tools/README.md`](../tools/README.md). This page only covers what you have to do.

## Before a PR: `make test`

`make test` (or `tests/run.sh`) runs only the suites your changes need, counted since your branch left `origin/main`, uncommitted files included. It takes about 30 s. `make test ALL=1` (`tests/run.sh --all`) runs everything. Keep it fast: it's meant to run often.

- **One kind of suite:** `tests/run.sh --lua-only` or `--typescript-only`. `.\tests\run.ps1` runs only the Pester suites (`-Path <file>` for one file, `-Name <pattern>` for matching tests, `-Repeat <n>` for [flaky tests](#flaky-tests)). `tests/run.sh --windows-powershell` runs them in Windows PowerShell 5.1 from WSL (serial, about 4 minutes).
- **One-time installs in WSL:** `sudo apt install parallel libicu78 luajit`. GNU parallel makes bats faster and LuaJIT runs the Lua tests. ICU is optional, since the tests pass without it. The rest gets fetched on the first run.
- CI runs the suites each PR needs, and all of them on pushes to `main`.

## Wiring a test in

- **Test filters:** [`.github/test-filters.json`](../.github/test-filters.json) says which suite depends on which files. It uses [dorny/paths-filter](https://github.com/dorny/paths-filter)'s format, which CI reads through that action and `make test` through `tools/select_tests.py`. Every file in the repo must match a filter (`none` for files that need no test), and every test file needs a filter of its own. The `pick tests` CI job and a Python unit test check both rules.
- **Every script change needs a test.** `deploy.sh` and `deploy.ps1` share one behavior spec, so a case added to `tests/deploy.bats` also goes in one of the `tests/Deploy*.Tests.ps1` files.
- **Pester:** each `tests/*.Tests.ps1` file runs in its own process, all at once. Keep each file under about 20 s, and split it by topic if it grows past that (as `Deploy*.Tests.ps1` does).
- **Lua:** luacheck lints the test extension's Lua and `tests/lua/`. When a file starts using an X4 global, add it to `.luacheckrc`. LuaUnit tests are `tests/lua/test_*.lua`, run under LuaJIT, which is the Lua X4 runs.
- **TypeScript tools** (`tools/`, Node 22.18 or later, packages from `make setup`): tests are `tools/**/*.test.ts`.
- **Python tools** in `tools/` are named with underscores (`check_test_plan.py`), so their unit tests in `tests/python/test_*.py` can import them. The tests use the standard library's `unittest`. The tools' bats tests stay as the end-to-end layer.
- **Diff-patch check** (`tools/check-diff-patches.ts`): it checks every diff patch's selectors against the unpacked 8.00 and SWI files (`X4_UNPACKED` and `SWI_UNPACKED` in `deploy.config`), and skips with a note when they're missing, as it does in CI.
- **Lowercase-paths check** (`tools/check-lowercase-paths.ts`): it runs with the TypeScript tools and fails when a shipped path (an entry in `deploy.include`, or anything under one) has an uppercase letter. A new `deploy.include` entry needs a matching glob in the `typescript` filter; a test fails until it has one.
- **Doc-size check** (`tools/check-doc-size.ts`, run with the TypeScript tools): it fails when `docs/PROJECT.md` goes over its size budget (set in the script). Move detail into a doc listed in PROJECT.md's "Where to look" table rather than raising the budget.
- **Doc-paths check** (`tools/check-doc-paths.ts`, also `make doc-paths`): it runs on every change and fails when a doc names a repo path that doesn't exist. Its filter is `**`, which doesn't count as covering a file. Add a rule in `tools/check-doc-paths/paths.ts` only for text that isn't a repo path.

## Flaky tests

A test that fails once and passes on a rerun is a bug, in the test or the code under it.

- **Log it:** open an issue with the run and job IDs before or right after rerunning. A rerun replaces what `gh run view --log-failed` shows; the failed attempt's log stays at `gh api repos/ecarlste/x4-pirates-life-mod/actions/jobs/<job-id>/logs --allow-escape-sequences`.
- **Measure it:** `.\tests\run.ps1 -Path <file> -Name '<pattern>' -Repeat 50` runs one Pester test 50 times and counts the failed runs. From WSL, run it in Windows PowerShell 5.1 with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)" …`, or in PowerShell 7 with `.tools/powershell-*/pwsh -NoProfile -File tests/run.ps1 …`. Several copies at once add load. If it stays green, widen the suspect timing window with a temporary sleep until it goes red, then fix the cause and show the rate before and after in the PR.
- **Make timing testable:** a script that polls a process or a file keeps that loop in a function a test can drive with a fake process or file (as `Watch-GameRun` in `tools/run-game-tests.ps1`), so its timing is tested every run instead of by luck.

## Test pyramid

Put each test at the lowest level that can prove the scenario:

1. Unit tests (LuaUnit in `tests/lua/`, Python in `tests/python/`)
2. UI tests (the same, with X4's menus stubbed; none on `main`, the settings page's are on `9.x`)
3. Game tests on the `apirateslife_test` start (`make game-test`)
4. By hand

MD and AI scripts only run inside X4, so what they do can't be tested below game tests. The goal is no manual UAT for releases, with a full CI/CD pipeline: by-hand scenarios are debt to drive to zero, and faster tests are better.

## Game tests

`make game-test` deploys the working tree. `tools/run-game-tests.ps1` then starts the X4 8.00 copy's `X4_nonsteam.exe` directly (no Steam) in its own test profile, with the dev-only test extension (`tests/game/apirateslife_tests`). The extension runs scripted scenarios in game and quits, and the runner reads the profile's `debuglog.txt` and reports PASS or FAIL. Profile IDs and paths are in [environment.md](environment.md#paths-eriks-machine).

- **First run:** `make game-test RUNNER_ARGS=-PrepareProfile` makes the test profile from the root profile's settings and switches on SWI, `apirateslife` and `apirateslife_tests`. Without that, the runner refuses to start. It also refuses while `X4` or `X4_nonsteam` is running.
- **The game lock:** it waits while another deploy or game run, from this repo or the bounty hunter's, holds the lock ([how it works](../tools/README.md#the-game-lock)).
- **Windows only**, and not in CI. Add a game test with each feature.
- **Reporting:** `make game-test-report` posts the report to your PR as a comment and a `game-tests` check. It works only if the run was on the PR's latest pushed commit, with nothing uncommitted.
- Background: [research/automated-game-testing.md](research/automated-game-testing.md).

## Test plan

`tests/game/features/*.feature` says in Gherkin (Given/When/Then) what each feature should do, one file per feature. Write a feature's scenarios with its spec, before the tests. Nothing executes the feature files; the steps live in the tests. Each scenario's tags say how it's verified:

- **The tests that cover it:** game tests by the name they report (e.g. `@pilot_bail_intact`), and unit tests by their test function's name (e.g. `@test_refuses_default_in_any_case`). Several tests can share a scenario.
- **`@pending`:** no test yet, but one is planned. Checked by hand until then.
- **`@manual`:** checked by hand for now, because automating it is hard (e.g. something surviving an X4 restart). Automation is still wanted.

Tests, `@pending` and `@manual` don't mix on one scenario. `tools/test_plan_docs.py --checklist <file>` writes every scenario still checked by hand as the release checklist.

- **Checks:** `make test` runs `tools/check_test_plan.py`. Every tag must name a game test or unit test, every game test needs a scenario (unit tests may cover details no scenario names), unit test names are unique, and every spec links its feature file. On PRs, `tools/check_test_plan_changes.py` fails when a spec or a game test changed but the plan didn't; the PR description then says `Test plan: no change`. Branch protection on `main` requires this check.
- **Readable test plan:** `docs/test-plan/` has a page per feature and an [index](test-plan/README.md) with the counts per feature, including **By hand** (manual plus pending), the number to drive to zero. Run **`make test-plan`** after changing feature files or tests, and commit the result. Don't edit the pages by hand. `make test` warns when they're out of date, and CI fails the PR.
