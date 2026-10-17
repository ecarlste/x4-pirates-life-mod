# A Pirate's Life — Project Context

Read this first. It is the shared context for anyone (and any tool) working on this repo.

## What this is

An X4: Foundations piracy overhaul: the one pirate mod a player needs, from small-time raider to pirate lord, playable as piracy alone. Base game first; designed so total conversions (Star Wars Interworlds) can plug in through data profiles.

- Extension ID: `apirateslife` (see `content.xml`)
- Full design: [`docs/DESIGN.md`](DESIGN.md) (exported from the living design doc, which is the source of truth)

## Key decisions

- **Target version:** latest X4 (9.x), vanilla first. SWI support comes later through a profile, once SWI ports to 9.x.
- **Required DLC:** Tides of Avarice (`ego_dlc_pirate`).
- **Profile-driven core:** no hardcoded vanilla faction/ship/ware/sector IDs in scripts. Universe-specific data lives in profiles; vanilla is the first profile.
- **Capture tiers are data**, not engine classes (vanilla S/M/L/XL; SWI adds XXL).
- **XML diff patches only** for library changes; never overwrite base files.
- **UI** builds on kuertee's UI Extensions and SirNukes' Mod Support APIs.
- **Filenames lowercase** (X4 3.0+ convention; matters for loose, uncatalogued files).
- **Build order:** core loop via standard vanilla starts first; custom starts and redemption later.

## Paths (Erik's machine)

| What | Path |
| --- | --- |
| Repo (WSL, Ubuntu 26.04) | `~/workspace/x4-pirates-life-mod` |
| X4 install | `E:\SteamLibrary\steamapps\common\X4 Foundations` → `/mnt/e/SteamLibrary/steamapps/common/X4 Foundations` |
| Deployed mod | `.../X4 Foundations/extensions/apirateslife` |
| Unpacked reference data (not in git) | `E:\x4-dev\reference\x4-9.xx\` → `/mnt/e/x4-dev/reference/x4-9.xx/` |
| Game profile per X4 version (saves, config, `debuglog.txt`) | `C:\Users\ecarl\OneDrive\Documents\Egosoft\X4\save_<version>\`, e.g. `save_9.00` (`save_7.60` is the frozen 7.60 copy for SWI) |
| X4 9.00 launch options (Steam) | `-personalfolderid "C:\Users\ecarl\OneDrive\Documents\Egosoft\X4\save_9.00" -skipintro -debug all -logfile debuglog.txt -scriptlogfiles` |

When X4 updates to a new version: re-unpack the game files into a new `x4-<version>` folder, point the launch options at a new `save_<version>` profile, and update this table.

## Workflow

- `make setup` once (creates `deploy.config` with the X4 install path), then deploy:
  - **"Deploy" means `make deploy`:** fetch and sync the latest `origin/main` into `extensions/apirateslife`, deleting files that left the mod. It deploys `main` no matter which branch is checked out.
  - `make deploy-local` syncs the working tree (uncommitted changes included) for in-game testing before a PR; `./deploy.sh --ref <branch>` deploys a pushed branch; `make deploy-dry-run` previews.
  - PowerShell equivalent: `.\deploy.ps1` (`-WorkingTree`, `-Ref <branch>`, `-DryRun`).
  - Only the paths in `deploy.include` ship; add new top-level mod folders there. Restart X4 after deploying.
- **Test scripts before a PR:** `make test` (or `tests/run.sh`) runs the bats suites, shellcheck when installed, and the Pester suites when PowerShell is available, including Windows PowerShell from WSL. `.\tests\run.ps1` runs just the Pester suites. Test frameworks are fetched on first run (bats into `.tools/`, Pester into `.tools/` or `%LOCALAPPDATA%` when the repo is on `\\wsl.localhost`). CI (`.github/workflows/tests.yml`) runs everything on Linux, macOS (stock bash 3.2) and Windows (PowerShell 5.1 and 7) for every PR.
  - Every script change needs a test; `deploy.sh` and `deploy.ps1` share one behavior spec, so a case added to `tests/deploy.bats` belongs in `tests/Deploy.Tests.ps1` too.
- Never commit game data or unpacked reference files.
- Research notes go in `docs/research/`, listed in its README; decisions get reflected back into the design doc.
- Design discussions happen in the design doc; build work happens locally in WSL. GitHub is the hub between them, so commit and push often.
- **All changes go through a feature branch and a pull request**, never straight to `main`. Erik reviews every PR, and an automated PR reviewer runs on it too. Branch names: `feature/…`, `fix/…`, `docs/…`, `spike/…`.
- **PRs are squash-merged** (the only merge option): the PR title becomes the commit title on `main` and the PR description becomes its body. Commits inside a branch can be informal. Merged branches are deleted automatically.
- **PR titles follow [Conventional Commits](https://www.conventionalcommits.org/):** `type(scope): summary`, checked by CI (`.github/workflows/pr-title.yml`). The check is required by branch protection on `main`, for admins too.
  - Types: `feat`, `fix`, `docs`, `test`, `ci`, `build`, `refactor`, `perf`, `style`, `chore`, `revert`. Add `!` for breaking changes, e.g. `feat(deploy)!: …`.
  - Scope is optional and names the area: `deploy`, `tests`, `tools`, `md`, `plan`, `research`, …
  - The whole title is **72 characters or fewer**, about where GitHub cuts commit titles off, so `main`'s commit list reads at a glance with no hovering. That's the whole purpose of the limit, so don't tighten it further. The ` (#123)` GitHub appends when squashing may get cut off, and that's fine. The summary names what changed in the terms someone would search for; anything that doesn't fit goes in the description, which GitHub search and `git log --grep` also cover.
- **PR descriptions are the commit body:** list every change by file or area, say what a reviewer should check closely, and note anything not tested or deliberately left out.
- **Commits and PRs are authored by Erik only** (`Erik S. Carlsten <ecarlste@gmail.com>`). No co-author trailers, no session links, and no tool attribution or "generated by" lines in commits, PR descriptions, or files.

## Planning docs

- [`DESIGN.md`](DESIGN.md): the high-level design, exported from the living design doc. Don't edit it here; it gets overwritten on the next export.
- [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md): the tracker for all agreed work.
- [`specs/`](specs/): one short spec per agreed feature.
- [`research/`](research/README.md): what we've learned about vanilla X4 (call flows, hooks, tuning). Check its index before digging through game files.
- When one doc refers to another, link the exact section (`DESIGN.md#roadmap`), not just the file.

## Keeping docs in sync

When one of these happens, update the matching docs in the same PR.

| When | Update |
| --- | --- |
| We agree to new work, however small or far off | Add it to `IMPLEMENTATION_PLAN.md` |
| A PR is opened for a plan item | Link the PR from the item |
| A PR finishes a plan item | Tick it off; if it has a spec, mark the spec Done in the spec and in `specs/README.md` |
| A feature's design is agreed | Write a spec from `specs/_template.md`, add it to `specs/README.md`, link it from the plan item |
| Building a feature changes its design | Update its spec |
| A design decision changes, or research changes the design | List the changes for the living design doc in the PR description (Erik updates it, then re-exports `DESIGN.md`) |
| A research note is added or changes status | Its row in `docs/research/README.md` |
| A research spike finishes | Notes in `docs/research/`; update the plan's order and items to match |
| A key decision changes (target version, DLC, architecture) | "Key decisions" above, and the design doc as in the row above |
| A setup step, command, or path changes | "Workflow" or "Paths" above |
| A script changes | Its tests in `tests/` (and `tools/README.md` for anything in `tools/`) |
| A new top-level mod folder is added (`md/`, `aiscripts/`, …) | `deploy.include`, or it won't ship |
| `deploy.config` gains or changes a setting | `deploy.config.example` |

## Current status

- Existing: the deploy and test tooling, plus an in-game smoke test script (`md/`). No gameplay changes yet.
- Next: see the first unticked items in [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) (Phase 0 setup, then spike 1).
