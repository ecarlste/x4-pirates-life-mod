# Coding standards

Judgement calls a reviewer checks in a diff (`/mattpocock-skills:code-review` reads this file). Anything mechanical belongs in a check that `make test` runs, not here. How to run and wire up tests is in [docs/testing.md](docs/testing.md); the workflow rules are in [docs/PROJECT.md](docs/PROJECT.md).

## Scripts and tools (PowerShell, shell, TypeScript)

- **Check whether a process has exited before reading its output, not after.** A read made after the exit check has everything the process wrote; the other order can miss lines it wrote just before exiting. Found in the game test runner's poll loop ([#151](https://github.com/ecarlste/x4-pirates-life-mod/pull/151)).
- **Polling loops live in a function a test can drive** with a fake process or file (as `Watch-GameRun` in `tools/run-game-tests.ps1`), so their timing is tested on every run, not by luck ([docs/testing.md, Flaky tests](docs/testing.md#flaky-tests)).
