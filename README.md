# A Pirate's Life

A piracy overhaul for **X4: Foundations**. The goal is a full career from small-time raider to pirate lord, playable as piracy alone. It's built on vanilla X4 9.x first, and designed so total conversions such as Star Wars Interworlds can plug in later.

**Status:** early development. So far the mod doubles the chance that a ship's crew bails when attacked, and captured ships arrive intact (no damage from the bailing pilot or the claiming marine); the real systems are planned in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).

## Requirements

- X4: Foundations 9.x with the **Tides of Avarice** DLC
- To develop: git, plus either
  - bash (WSL, Linux or macOS) and `make`; or
  - PowerShell (Windows PowerShell 5.1 or PowerShell 7)
- To unpack game files for reference: Egosoft's **X Tools** from the Steam library

## Setup

```bash
git clone git@github.com:ecarlste/x4-pirates-life-mod.git
cd x4-pirates-life-mod
make setup          # creates deploy.config; on Ubuntu, `sudo apt install make` first
```

Edit `deploy.config` and set `X4_PATH` to your X4 install folder. Windows paths like `E:\SteamLibrary\...` work from WSL too. On PowerShell, copy `deploy.config.example` to `deploy.config` instead of running `make setup`.

Then check what a deploy would do, and deploy:

```bash
make deploy-dry-run
make deploy
```

Start X4 and check that **A Pirate's Life** is enabled under Extensions. For now the mod can be added to and removed from existing saves.

## Everyday commands

| Task | bash | PowerShell |
| --- | --- | --- |
| Deploy the latest `main` | `make deploy` | `.\deploy.ps1` |
| Deploy your working copy, uncommitted changes included | `make deploy-local` | `.\deploy.ps1 -WorkingTree` |
| Deploy a pushed branch | `./deploy.sh --ref <branch>` | `.\deploy.ps1 -Ref <branch>` |
| Deploy with a setting changed (deployed copy only) | `make deploy-local ARGS="--set IntactOnEject=0"` | `.\deploy.ps1 -WorkingTree -Set IntactOnEject=0` |
| Run the tests | `make test` | `.\tests\run.ps1` |
| Run the in-game tests in X4 (Windows) | `make game-test` | `.\deploy.ps1 -WorkingTree; .\tools\run-game-tests.ps1` |
| Post the last game-test report to your PR | `make game-test-report` | (bash only for now) |

Restart X4 after each deploy. For debugging, set X4's launch options (Steam: Properties → General) to

```
-skipintro -debug all -logfile debuglog.txt -scriptlogfiles
```

The log is written to your X4 profile folder, `<Documents>\Egosoft\X4\<Steam account ID>\debuglog.txt` for the Steam version.

## Repo layout

| Path | What |
| --- | --- |
| `content.xml`, `md/` | The mod itself; `deploy.include` lists everything that ships |
| `deploy.sh`, `deploy.ps1` | Sync the mod into the game |
| `tools/` | Dev scripts, such as unpacking the game files ([`tools/README.md`](tools/README.md)) |
| `tests/` | bats and Pester suites; CI runs them on Linux, macOS and Windows. `tests/game/` holds the dev-only extension for in-game tests |
| `docs/` | Project context, design, plan and specs (below) |

## Docs

- [`docs/PROJECT.md`](docs/PROJECT.md): **read first.** Key decisions, workflow rules, and which docs to update when.
- [`docs/DESIGN.md`](docs/DESIGN.md): the high-level design.
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md): every agreed piece of work, with checkboxes.
- [`docs/specs/`](docs/specs/): one spec per feature, written before it's built.
- [`docs/research/`](docs/research/README.md): what we've learned about how vanilla X4 works.

## Coming back after a break

1. `git switch main && git pull`
2. Check open PRs and their CI runs on GitHub.
3. Read the first unticked items in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md); that's where work picks up.
4. If X4 updated, re-unpack the game files (`tools/unpack-x4.ps1 -Version <new version>`) and note anything that broke.
5. `make test`, then `make deploy` and check the mod still loads in game.
