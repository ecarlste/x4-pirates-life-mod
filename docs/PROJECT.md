# A Pirate's Life — Project Context

Read this first. It is the shared context for anyone (and any tool) working on this repo.

## What this is

An X4: Foundations piracy overhaul: the one pirate mod a player needs, from small-time raider to pirate lord, playable as piracy alone. Base game first; designed so total conversions (Star Wars Interworlds) can plug in through data profiles.

- Extension ID: `apirateslife` (see `content.xml`)
- Full design: [`docs/DESIGN.md`](DESIGN.md), the source of truth for the agreed design

## Key decisions

- **Target version:** latest X4 (9.x), vanilla first. SWI support comes later through a profile, once SWI ports to 9.x.
- **Required DLC:** Tides of Avarice (`ego_dlc_pirate`).
- **Profile-driven core:** no hardcoded vanilla faction/ship/ware/sector IDs in scripts. Universe-specific data lives in profiles; vanilla is the first profile.
- **Use X4's own systems, always:** do things with existing assets, traffic, stations and economy, and rely on the game's natural systems. Magic (spawning ships, wares or stations, adding credits or cargo, effects with no cause in the universe) only when there's no organic way and fun needs it. See [DESIGN.md, Design pillars](DESIGN.md#design-pillars-and-compatibility-architecture).
- **Capture tiers are data**, not engine classes (vanilla S/M/L/XL; SWI adds XXL).
- **XML diff patches only** for library changes; never overwrite base files.
- **UI** builds on kuertee's UI Extensions (actively maintained, and what SWI uses), declared as an optional dependency with the mod working without it. SirNukes' Mod Support APIs only where there's no alternative (not updated since Dec 2025; unreliable on 9.0). See [research/third-party-ui-apis.md](research/third-party-ui-apis.md).
- **Filenames lowercase** (X4 3.0+ convention; matters for loose, uncatalogued files).
- **Build order:** core loop via standard vanilla starts first; custom starts and redemption later.

## Paths (Erik's machine)

| What | Path |
| --- | --- |
| Repo (WSL, Ubuntu 26.04) | `~/workspace/x4-pirates-life-mod` |
| X4 install | `E:\SteamLibrary\steamapps\common\X4 Foundations` → `/mnt/e/SteamLibrary/steamapps/common/X4 Foundations` |
| Deployed mod | `.../X4 Foundations/extensions/apirateslife` |
| Unpacked reference data (not in git) | `E:\x4-dev\reference\x4-9.xx\` → `/mnt/e/x4-dev/reference/x4-9.xx/`; other mods for study in `E:\x4-dev\reference\mods\` |
| Steam Workshop mods | X4 installs them into the game's `extensions\` folder itself (not Steam's workshop folder), syncing when the game starts |
| X4 9.00 profile (saves, config, `debuglog.txt`) | Steam profile: `C:\Users\ecarl\OneDrive\Documents\Egosoft\X4\28456535\` (folder named after the Steam account ID). The in-game menu shows save slots 1–10 |
| X4 9.00 launch options (Steam) | `-skipintro -debug all -logfile debuglog.txt -scriptlogfiles` |
| X4 8.00 HF4 copy for SWI (NoSteam) | `E:\SteamLibrary\steamapps\common\X4 Foundations - 8.00`, started by the `X4_8.00` desktop shortcut (`X4_nonsteam.exe` with the launch options above). `extensions\` has only the DLCs and SWI 0.90 (`starwarsmod_m1`); other mods get installed by hand. The NoSteam download is kept in `E:\x4-dev\nosteam-8.00\` (9.00's in `nosteam-9.00\`) |
| X4 8.00 profile | The root folder `…\Egosoft\X4\`, which NoSteam uses by default. The old 7.60 profile and saves (they don't load in 8.00) are backed up in `E:\x4-dev\backups\x4-root-profile-7.60-2026-10-30\` |

`-personalfolderid` gives a separate profile only with a numeric ID (the 2026-10-28 NoSteam spike made `…\Egosoft\X4\90000001\`); with a full path or a plain folder name (tested 2026-10-17/18), X4 falls back to the root folder.

When X4 updates to a new version: re-unpack the game files into a new `x4-<version>` folder and update this table.

## Workflow

- `make setup` once (creates `deploy.config` with the X4 install path), then deploy:
  - **"Deploy" means `make deploy`:** fetch and sync the latest `origin/main` into `extensions/apirateslife`, deleting files that left the mod. It deploys `main` no matter which branch is checked out.
  - `make deploy-local` syncs the working tree (uncommitted changes included) for in-game testing before a PR; `./deploy.sh --ref <branch>` deploys a pushed branch; `make deploy-dry-run` previews.
  - PowerShell equivalent: `.\deploy.ps1` (`-WorkingTree`, `-Ref <branch>`, `-DryRun`).
  - **Settings for a test deploy:** `--set NAME=VALUE` (PowerShell `-Set`) overrides a value from `md/apirateslife_config.xml` in the deployed copy only, e.g. `make deploy-local ARGS="--set IntactOnEject=0"`. Repeat it or use commas; unknown names fail. The next deploy without it restores the committed values.
  - Only the paths in `deploy.include` ship; add new top-level mod folders there. Restart X4 after deploying.
- **Game tests:** `make game-test` deploys the working tree, then `tools/run-game-tests.ps1` starts X4 through Steam (so the Steam launch options must write `debuglog.txt`) with the dev-only test extension (`tests/game/apirateslife_tests`), which runs scripted scenarios in game and quits; the runner reports PASS/FAIL. Windows only, not in CI. Add a game test with each feature. `make game-test-report` then posts the report to your PR (comment plus a `game-tests` check), if the run was on the PR's latest pushed commit with nothing uncommitted. See [research/automated-game-testing.md](research/automated-game-testing.md).
- **Test scripts before a PR:** `make test` (or `tests/run.sh`) runs the bats suites, shellcheck when installed, the Lua and Python unit tests, and the Pester suites, in about 30 s. Keep it fast: it's meant to run often. Pester runs under PowerShell 7 (`pwsh` if installed, else Microsoft's Linux build fetched into `.tools/`, pinned by SHA-256), one process per `tests/*.Tests.ps1` file, all at once and in the background while the other suites run; so keep each test file small enough to finish in under about 20 s, splitting it by topic if not (as `Deploy*.Tests.ps1`). bats runs its files in parallel when GNU parallel is installed. For the fastest run: `sudo apt install parallel libicu78` (without ICU, PowerShell runs in .NET's invariant-globalization mode, which the tests don't notice). CI runs the Pester suites under Windows PowerShell 5.1 and PowerShell 7 on every PR; `tests/run.sh --windows-powershell` runs them in Windows PowerShell 5.1 from WSL (serial, about 4 minutes). `.\tests\run.ps1` runs just the Pester suites (`-Path <file>` for one file). Test frameworks are fetched on first run (bats into `.tools/`, Pester into `.tools/` or `%LOCALAPPDATA%` when the repo is on `\\wsl.localhost`). Pester is downloaded from the PowerShell Gallery's CDN, with its API as a fallback, and checked against the SHA-256 pinned in `tests/run.ps1`; to bump Pester, update the version and the hash together. CI caches `.tools/`. The Lua checks (`tests/lua/run.sh`, also `tests/run.sh --lua-only`) lint `ui/`, the test extension's Lua and `tests/lua/` with luacheck (`.luacheckrc` lists the X4 globals we use; add one there when a file starts using it), then run the LuaUnit tests in `tests/lua/test_*.lua` under LuaJIT, the Lua X4 runs, with X4's functions stubbed by `tests/lua/x4stubs.lua`. luacheck and LuaUnit are fetched into `.tools/`, pinned by SHA-256; LuaJIT needs a one-time `sudo apt install luajit`. Each skips with a note when it can't run (luacheck has no macOS build); CI runs both in its Lua job. The settings page shows its local functions to the tests through `APiratesLife_TestHooks`, which X4 never sets. The Python tools in `tools/` have unit tests in `tests/python/test_*.py` (the standard library's `unittest`, nothing to install), run by `make test` with `tools/` on `PYTHONPATH`; their bats tests stay as the end-to-end layer. Python tools are named with underscores (`check_test_plan.py`) so the tests can import them. CI (`.github/workflows/tests.yml`) runs on every PR where each script is used: shellcheck, bats and the Lua checks on Linux (the bash tooling runs in WSL), and the Pester suites on Windows under Windows PowerShell 5.1 and PowerShell 7 (the PowerShell scripts run on Windows). macOS isn't tested.
- **Test pyramid:** put each test at the lowest level that can prove the scenario: unit tests (LuaUnit, local and CI, `tests/lua/`) > UI tests (the same, with the options menu's dialogs and callbacks stubbed) > game tests on the `apirateslife_test` start (`make game-test`) > by hand. MD and AI scripts only run inside X4, so what they do can't go below game tests. The goal is no manual UAT for releases, with a full CI/CD pipeline: by-hand scenarios are debt to drive to zero, and faster tests are better.
- **Test plan:** `tests/game/features/*.feature` says in Gherkin (Given/When/Then) what each feature should do, one file per feature. Each scenario's tags say how it's verified:
  - the tests that cover it: game tests by the name they report (e.g. `@pilot_bail_intact`), unit tests (LuaUnit in `tests/lua/`, or Python in `tests/python/`, such as the variant generator's) by their test function's name (e.g. `@test_refuses_default_in_any_case`); several tests can share a scenario;
  - `@pending`: no test yet, one is planned; checked by hand until then;
  - `@manual`: checked by hand for now, because automating it is hard (e.g. something surviving an X4 restart); automation is still wanted.
  Tests, `@pending` and `@manual` don't mix on one scenario. `tools/test_plan_docs.py --checklist <file>` writes every scenario still checked by hand (`@manual` and `@pending`) as the release checklist. Write the scenario with the spec, before the test. `make test` runs `tools/check_test_plan.py`: every tag must name a game test or unit test, every game test needs a scenario (unit tests may cover details no scenario names), unit test names are unique, and every spec links its feature file. On PRs, `tools/check_test_plan_changes.py` fails when a spec or a game test changed but the plan didn't (see the PR description rule below); like the PR-title check, it's required by branch protection on `main`. Nothing executes the feature files; the steps live in the tests.
  - **Readable test plan:** `docs/test-plan/` has a page per feature and an index ([`docs/test-plan/README.md`](test-plan/README.md)) with every scenario's steps, how it's verified, and the counts per feature, including **By hand** (manual plus pending), the number to drive to zero. They're generated from the feature files and tests by **`make test-plan`**: run it after changing either, and commit the result. Don't edit the pages. `make test` warns at the end when they're out of date, without failing; CI (the test-plan check) fails the PR.
  - Every script change needs a test; `deploy.sh` and `deploy.ps1` share one behavior spec, so a case added to `tests/deploy.bats` belongs in one of the `tests/Deploy*.Tests.ps1` files too.
- **Pirate variants** are generated: list them in `profiles/vanilla/variants.xml`, then `make variants` (needs the unpacked game files) writes them into the mod, with `profiles/vanilla/variants.manifest` (a stamp of the list and generator, and a hash of each generated file); commit all of it. `make test` and CI check that the generated files still match the list (by the manifest, as CI has no game files). See `tools/README.md`.
- Never commit the unpacked reference files, or game files copied unchanged. Modified copies of vanilla files that the mod ships (diff patches, generated variant macros) are fine.
- Research notes go in `docs/research/`, listed in its README.
- **Ideas move through three stages:** brainstorming and open questions stay in research notes and under "Ideas and maybe" in the plan; once Erik signs off that we *will* do something, it goes into `DESIGN.md`; when it's about to be built, it gets a spec. Don't put undecided ideas in `DESIGN.md` or specs.
- **Erik signs off every design change, whoever proposes it** (Claude, another developer, a research spike). Propose changes in a "Design proposals" section of the PR description, or discuss them in chat; edit `DESIGN.md` only after Erik has explicitly agreed, in chat or on the PR. A PR that changes `DESIGN.md` says so in its title or description, so a design change is never buried in other work.
- **Erik decides each piece of a proposal: accept, keep iterating, or reject.** A proposal can be split, with different pieces getting different outcomes.
  - *Accepted:* goes into `DESIGN.md`.
  - *Keep iterating:* stays in its research note (or under "Ideas and maybe") to be researched or reworked.
  - *Rejected:* moves out of research into [`rejected/`](rejected/README.md), with a rejection notice at the top of its file (date, reason, links to the full reasons and to [reopening](rejected/README.md#reopening-a-rejected-idea)), so it's kept and easy to find but isn't proposed again unchanged. Reopening a rejected idea, e.g. because someone thinks they've solved the reason it was rejected, needs Erik's approval; then it moves back into research.
- Before proposing a design idea, check [`rejected/`](rejected/README.md) for it.
- Design discussions happen in chat; build work happens locally in WSL. GitHub is the hub, so commit and push often.
- **All changes go through a feature branch and a pull request**, never straight to `main`. Erik reviews every PR, and an automated PR reviewer runs on it too. Branch names: `feature/…`, `fix/…`, `docs/…`, `spike/…`.
- **PRs are squash-merged** (the only merge option): the PR title becomes the commit title on `main` and the PR description becomes its body. Commits inside a branch can be informal. Merged branches are deleted automatically.
- **PR titles follow [Conventional Commits](https://www.conventionalcommits.org/):** `type(scope): summary`, checked by CI (`.github/workflows/pr-title.yml`). The check is required by branch protection on `main`, for admins too.
  - Types: `feat`, `fix`, `docs`, `test`, `ci`, `build`, `refactor`, `perf`, `style`, `chore`, `revert`. Add `!` for breaking changes, e.g. `feat(deploy)!: …`.
  - Scope is optional and names the area: `deploy`, `tests`, `tools`, `md`, `plan`, `research`, …
  - The whole title is **72 characters or fewer**, about where GitHub cuts commit titles off, so `main`'s commit list reads at a glance with no hovering. That's the whole purpose of the limit, so don't tighten it further. The ` (#123)` GitHub appends when squashing may get cut off, and that's fine. The summary names what changed in the terms someone would search for; anything that doesn't fit goes in the description, which GitHub search and `git log --grep` also cover.
- **PR descriptions are the commit body:** list every change by file or area, say what a reviewer should check closely, and note anything not tested or deliberately left out.
  - A **Test plan** section lists the scenarios added, changed and still pending. If a PR changes a spec or a game test but not the plan (a typo fix, say), write `Test plan: no change` instead; the test-plan PR check fails otherwise.
- **Commits and PRs are authored by Erik only** (`Erik S. Carlsten <ecarlste@gmail.com>`). No co-author trailers, no session links, and no tool attribution or "generated by" lines in commits, PR descriptions, or files.

## Planning docs

- [`DESIGN.md`](DESIGN.md): the agreed high-level design, edited here through PRs like everything else. Only decided design goes in; ideas still being explored stay in research notes and the plan's "Ideas and maybe".
- [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md): the tracker for all agreed work.
- [`specs/`](specs/): one short spec per agreed feature.
- [`research/`](research/README.md): what we've learned about vanilla X4 (call flows, hooks, tuning), and design ideas still being worked on. Check its index before digging through game files.
- [`rejected/`](rejected/README.md): design ideas Erik rejected, and why. Check it before proposing an idea.
- When one doc refers to another, link the exact section (`DESIGN.md#roadmap`), not just the file.

## Keeping docs in sync

When one of these happens, update the matching docs in the same PR.

| When | Update |
| --- | --- |
| We agree to new work, however small or far off | Add it to `IMPLEMENTATION_PLAN.md` |
| A PR is opened for a plan item | Link the PR from the item |
| A PR finishes a plan item | Tick it off; if it has a spec, mark the spec Done in the spec and in `specs/README.md` |
| A feature's design is agreed | Write a spec from `specs/_template.md`, add it to `specs/README.md`, link it from the plan item; write its scenarios in `tests/game/features/` (tagged `@pending`) |
| A game test or unit test is added, renamed or changes what it checks | Its scenarios in `tests/game/features/`: tag them with the test's name; then `make test-plan` |
| A test now covers a `@pending` or `@manual` scenario | Swap the tag for the test's name; then `make test-plan` |
| A spec's behaviour changes (requirements, thresholds, outcomes) | Its scenarios in `tests/game/features/`, in the same PR; then `make test-plan` |
| Building a feature changes its design | Update its spec |
| Erik signs off a design choice or change | `DESIGN.md`, in the same PR as the work or its own `docs/` PR |
| Research or other work suggests a design change not yet signed off | A "Design proposals" list in the PR description; not `DESIGN.md` |
| Erik rejects a design idea | Move it from its research note (or "Ideas and maybe") into a file in `docs/rejected/` made from `_template.md`, with the rejection notice at the top, and add its row to `docs/rejected/README.md`; leave a one-line pointer where it was |
| Erik approves reopening a rejected idea | Move it back into research, drop its rejection notice, and remove its row from `docs/rejected/README.md` ([how](rejected/README.md#reopening-a-rejected-idea)) |
| A research note is added or changes status | Its row in `docs/research/README.md` |
| A research spike finishes | Notes in `docs/research/`; update the plan's order and items to match |
| A key decision changes (target version, DLC, architecture) | "Key decisions" above, and `DESIGN.md` |
| A setup step, command, or path changes | "Workflow" or "Paths" above |
| A script changes | Its tests in `tests/` (and `tools/README.md` for anything in `tools/`) |
| A new top-level mod folder is added (`md/`, `aiscripts/`, …) | `deploy.include`, or it won't ship |
| `deploy.config` gains or changes a setting | `deploy.config.example` |

## Current status

- Existing: the deploy and test tooling, an in-game smoke test script, and the bail hook (`md/`): every bail check runs through our code (currently 2x chance) and every bail raises our `Bailed` signal; captured ships arrive intact (no pilot-bail hull drop or sabotage, no marine-claim damage), each switchable to vanilla in the config file (`md/apirateslife_config.xml`), tested in game. Capture operations started from a comm choice: wingmen break a target to a hold line and then only keep its shields down, with a mission readout ([spec](specs/capture-operation.md)). In-game settings ([spec](specs/in-game-settings.md)): with kuertee's UI Extensions, Settings → A Pirate's Life switches the three player-facing settings; a game is on a profile (Default, the config file, or one saved in the X4 profile and shared by every save) and follows it until a setting is changed ([spec](specs/settings-profiles.md)). Capture metrics: one summary line per capture attempt in `debuglog.txt`, and `tools/capture_metrics.py` to turn logs into a CSV ([spec](specs/capture-metrics.md)). Pirated ships: every ship that becomes the player's is marked pirated (taken by boarding or bailing in combat with the player's ships) or a donation, for booty ([spec](specs/pirated-ships.md)). Booty, first part ([spec](specs/booty.md)): talk to the manager or ship trader of a Vigor wharf or shipyard to hand docked ships over for credits (a sale minus the fence's cut) and booty, which raises standing with Vigor through 21 levels; the sale is done by our Lua the way vanilla's map sells ships. A "Hand over as booty" order flies a ship to the nearest Vigor station that takes it and hands it over, and a handover moves the prize's pilot to a marine slot on the nearest ship with room. Automated in-game tests (`make game-test`) covering the bail hook, intact captures, capture operations, capture metrics, pirated ships, booty and the settings bridge.
- Next: see the first unticked items in [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) (Phase 0 setup, then spike 1).
