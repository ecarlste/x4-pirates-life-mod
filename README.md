# A Pirate's Life

A piracy overhaul for **X4: Foundations**. The goal is a full career from small-time raider to pirate lord, playable as piracy alone. It's built on vanilla X4 9.x first, and designed so total conversions such as Star Wars Interworlds can plug in later.

**Status:** early development. The mod currently makes NPC crews bail out about twice as often as vanilla; the real systems are planned in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).

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
| Run the tests | `make test` | `.\tests\run.ps1` |

Restart X4 after each deploy. For debugging, set X4's launch options (Steam: Properties → General) to

```
-personalfolderid "<Documents>\Egosoft\X4\save_<version>" -skipintro -debug all -logfile debuglog.txt -scriptlogfiles
```

This gives each X4 version its own profile folder, holding its saves, settings and `debuglog.txt`.

## Repo layout

| Path | What |
| --- | --- |
| `content.xml`, `libraries/` | The mod itself; `deploy.include` lists everything that ships |
| `deploy.sh`, `deploy.ps1` | Sync the mod into the game |
| `tools/` | Dev scripts, such as unpacking the game files ([`tools/README.md`](tools/README.md)) |
| `tests/` | bats and Pester suites; CI runs them on Linux, macOS and Windows |
| `docs/` | Project context, design, plan and specs (below) |

## Docs

- [`docs/PROJECT.md`](docs/PROJECT.md): **read first.** Key decisions, workflow rules, and which docs to update when.
- [`docs/DESIGN.md`](docs/DESIGN.md): the high-level design.
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md): every agreed piece of work, with checkboxes.
- [`docs/specs/`](docs/specs/): one spec per feature, written before it's built.

## Coming back after a break

1. `git switch main && git pull`
2. Check open PRs and their CI runs on GitHub.
3. Read the first unticked items in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md); that's where work picks up.
4. If X4 updated, re-unpack the game files (`tools/unpack-x4.ps1 -Version <new version>`), point the launch options at a new `save_<version>` profile, and note anything that broke.
5. `make test`, then `make deploy` and check the mod still loads in game.
