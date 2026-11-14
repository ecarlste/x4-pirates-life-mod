# Coding standards

Judgement calls a reviewer checks in a diff (`/mattpocock-skills:code-review` reads this file). Anything mechanical belongs in a check that `make test` runs, not here. How to run and wire up tests is in [docs/testing.md](docs/testing.md); the workflow rules are in [docs/PROJECT.md](docs/PROJECT.md).

## MD scripts

- **Every property an MD expression uses exists for its datatype** in the unpacked `libraries/scriptproperties.xml` ([docs/environment.md, Paths](docs/environment.md#paths-eriks-machine)). X4 reads an unknown property as null and gives no error, so `indexof` on a string (only lists and groups have it) silently checks nothing. Found in the release tests ([#187](https://github.com/ecarlste/x4-pirates-life-mod/pull/187)).
- **A check in a game test has been seen failing at least once**, or the PR says its failing side is untested. A check that can't fail passes in X4 while proving nothing.
- **MD reads 0 as null**: compare values that can be 0 as `'%s'` text, or with `?`. Otherwise a stored 0 and a missing value look the same, as `ReleaseLeftovers` found ([#176](https://github.com/ecarlste/x4-pirates-life-mod/issues/176)).

## Scripts and tools (PowerShell, shell, TypeScript)

- **Check whether a process has exited before reading its output, not after.** A read made after the exit check has everything the process wrote; the other order can miss lines it wrote just before exiting. Found in the game test runner's poll loop ([#151](https://github.com/ecarlste/x4-pirates-life-mod/pull/151)).
- **Polling loops live in a function a test can drive** with a fake process or file (as `Watch-GameRun` in `tools/run-game-tests.ps1`), so their timing is tested on every run, not by luck ([docs/testing.md, Flaky tests](docs/testing.md#flaky-tests)).
