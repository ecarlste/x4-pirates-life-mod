# Implementation Plan

Everything we've agreed to do, by phase. Tick items off in the PR that finishes them, and link the PR. Feature items link their spec in [`specs/`](specs/) once one exists. Later phases are guesses: reorder them freely.

## Phase 0: Dev setup and tooling

Everything needed to build, deploy, test and debug the mod comfortably.

**Environment**

- [x] Check Windows version (Windows 11 25H2, build 26200)
- [x] Move WSL off C: (fresh Ubuntu 26.04 at `E:\wsl\Ubuntu-26.04`)
- [x] Install `gh` in WSL and `gh auth login`
- [x] Install `make` in WSL
- [x] Install X Tools from Steam (XRCatTool, WorkshopTool)
- [x] Script to unpack the base game and DLCs: `tools/unpack-x4.ps1` ([PR #2](https://github.com/ecarlste/x4-pirates-life-mod/pull/2))
- [x] Unpack 9.00 into `E:\x4-dev\reference\x4-9.00\`; the first run found and fixed a script bug ([PR #6](https://github.com/ecarlste/x4-pirates-life-mod/pull/6))
- [ ] Point VS Code at `md.xsd` and `aiscripts.xsd` for MD and AI script validation
- [x] Launch options for 9.00: debug and script logging; 9.00 uses the Steam profile folder, since `-personalfolderid` didn't give a separate profile (see [PROJECT.md, Paths](PROJECT.md#paths-eriks-machine))

**Deploy and test tooling**

- [x] `make deploy` syncs the latest `origin/main` into the game; working-tree and branch deploys; PowerShell twin ([PR #3](https://github.com/ecarlste/x4-pirates-life-mod/pull/3))
- [x] bats and Pester test suites for all scripts, run locally and in CI on Linux, macOS and Windows ([PR #3](https://github.com/ecarlste/x4-pirates-life-mod/pull/3))
- [x] Squash-only merges using the PR title and description, merged branches auto-deleted; Conventional Commits PR titles (72 characters max) required by a CI check ([PR #10](https://github.com/ecarlste/x4-pirates-life-mod/pull/10))
- [ ] Autoformat scripts on commit: shfmt and PSScriptAnalyzer's formatter, through a pre-commit hook enabled by `make setup`
- [ ] `make release`: lint (shellcheck, PSScriptAnalyzer default rules, format check), run the tests, build the release zip from a clean `origin/main`; drop linting from `make test` and PR CI
- [x] Repo README: what the mod is, prerequisites, setup, deploy, test, coming back after a break ([PR #5](https://github.com/ecarlste/x4-pirates-life-mod/pull/5))

**In-game dev tooling** (from [DESIGN.md, Roadmap](DESIGN.md#roadmap): "Dev tooling, early")

- [x] Smoke test proving the mod runs in game, and the first real `make deploy` ([PR #11](https://github.com/ecarlste/x4-pirates-life-mod/pull/11)): an MD script that writes to `debuglog.txt` (`debug_text`) and shows an on-screen notification (`show_notification`) on `event_game_started` / `event_game_loaded`, plus a log line when a ship is abandoned (`event_object_abandoned`) or attacked (`event_object_attacked`)
- [ ] Showcase/test gamestart
- [ ] Dev menu, stripped from release builds
- [ ] Versioned showcase saves, one per feature

## Phase 1: Spike 1, how bailing and boarding work in vanilla

Research before building. Deliverable: [`docs/research/spike-1-bailing-boarding.md`](research/spike-1-bailing-boarding.md) (WIP: bailing mostly mapped), covering call flow, tuning knobs, what we can hook vs. patch, and blockers for wingman bails and Raid Sector. See [DESIGN.md, Roadmap](DESIGN.md#roadmap): "Spike 1".

- [ ] Bailing (S/M): triggers, player vs. NPC attackers, what happens to the ship afterward, whether wingmen and fleets can cause and claim bails
- [ ] Boarding (L/XL): the full flow, `parameters.xml` tuning vs. engine behavior, NPC boarding, how the boarding UI talks to MD
- [ ] Adjacent: cargo drop demands, faction reactions to theft, the Yaki IFF disguise
- [ ] Prior art: study Better Piracy (the original on [GitHub](https://github.com/AlbertoRota/x4-Better-piracy) and the 9.x version on Steam Workshop): its features, how it implements them, and where we differentiate. Read only; its code has no license, so nothing is copied. WIP: [research note](research/prior-art-better-piracy.md)
- [x] Find where the bail chance actually lives: `PlayerOwnedShipAttacks` in `md/notifications.xml` ([research note](research/spike-1-bailing-boarding.md)). The old `libraries/god.xml` patch was removed: 9.00 has no bail value there, and X4 merged the non-`<diff>` file as god data, logging errors on every new game
- [ ] Bring back the mod's 2x bail rate as an MD diff patch on `PlayerOwnedShipAttacks` (the candidate hook in the research note): [spec](specs/bail-hook.md)
- [ ] Reflect findings back into the design doc, then confirm the order of the Phase 2 slices

## Phase 2: Core loop vertical slices

Each slice is demo-able and gets a video. Each one goes through: design agreed, spec written, built, tested in game, showcase save recorded, video. The order is provisional until spike 1 is done.

- [ ] 1. Wingman forces an S ship to bail; a prize crew flies it home
- [ ] 2. Notoriety and heat v1, with bail chance tied to notoriety
- [ ] 3. Fencing and hot-goods pricing at pirate docks
- [ ] 4. Raid Sector fleet order
- [ ] 5. M capture with prisoners, ransom and laundering
- [ ] 6. Bounty hunters v1
- [ ] 7. L boarding through Hunt Large Targets
- [ ] 8. Hideout
- [ ] 9. Difficulty presets and mod options menu

## Phase 3: Late career and story (predicted)

- [ ] XL capture set pieces
- [ ] Fear vs. honor reputation ([design](DESIGN.md#notoriety-heat-and-fear-vs-honor); settle its [open questions](DESIGN.md#open-questions) first)
- [ ] Pirate lord systems: protection rackets, lane taxes, blockades
- [ ] Redemption arc, per faction
- [ ] Prison break custom start
- [ ] Named recurring bounty hunters (nemesis system)

## Phase 4: Release and distribution (predicted)

- [ ] Versioning scheme and changelog
- [ ] Publish to Steam Workshop (WorkshopTool) and Nexus
- [ ] Publish `INTEGRATION.md`: the profile format, MD signals and hooks, API version

## Phase 5: Total conversion support (predicted)

- [ ] Profile contract hardened against a second universe
- [ ] Ask the SWI team before shipping an SWI profile
- [ ] SWI profile, once SWI supports 9.x, including XXL capture tiers

## Ideas and maybe

Not yet agreed. Promote an item into a phase once we decide to do it.

- [ ] PSScriptAnalyzer and shellcheck in PR CI as well as at release
