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
- [x] `deploy --set NAME=VALUE` (PowerShell `-Set`): override config settings in the deployed copy only, for testing ([PR #22](https://github.com/ecarlste/x4-pirates-life-mod/pull/22))
- [ ] Autoformat scripts on commit: shfmt and PSScriptAnalyzer's formatter, through a pre-commit hook enabled by `make setup`
- [ ] `make release`: lint (shellcheck, PSScriptAnalyzer default rules, format check), run the tests, build the release zip from a clean `origin/main`; drop linting from `make test` and PR CI
- [x] Repo README: what the mod is, prerequisites, setup, deploy, test, coming back after a break ([PR #5](https://github.com/ecarlste/x4-pirates-life-mod/pull/5))

**In-game dev tooling** (from [DESIGN.md, Roadmap](DESIGN.md#roadmap): "Dev tooling, early")

- [x] Smoke test proving the mod runs in game, and the first real `make deploy` ([PR #11](https://github.com/ecarlste/x4-pirates-life-mod/pull/11)): an MD script that writes to `debuglog.txt` (`debug_text`) and shows an on-screen notification (`show_notification`) on `event_game_started` / `event_game_loaded`, plus a log line when a ship is abandoned (`event_object_abandoned`) or attacked (`event_object_attacked`)
- [ ] Showcase/test gamestart (the game tests' gamestart below covers testing; a showcase start is still to do)
- [x] Automated in-game regression tests: a dev-only test extension (test gamestart, MD tests, Lua autostart) and a runner that starts X4, reads the results from `debuglog.txt` and reports PASS/FAIL (`make game-test`): [research note](research/automated-game-testing.md). Proof of concept built with tests for the bail hook and intact captures ([PR #20](https://github.com/ecarlste/x4-pirates-life-mod/pull/20)); first in-game run: 3 of 3 pass ([PR #28](https://github.com/ecarlste/x4-pirates-life-mod/pull/28))
- [x] Game-test plan in Gherkin: one `.feature` file per feature in `tests/game/features/`, scenarios tagged with the game test that covers them or `@pending`, checked against the tests by `make test`
- [x] Game tests for the capture settings: each intact flag off gives vanilla damage ([PR #29](https://github.com/ecarlste/x4-pirates-life-mod/pull/29))
- [x] `make game-test-report`: post the last game-test report to the branch's PR as a comment and a `game-tests` commit status, only when it's for the PR's latest commit with nothing uncommitted ([PR #30](https://github.com/ecarlste/x4-pirates-life-mod/pull/30))
- [ ] Dev menu, stripped from release builds
- [ ] Versioned showcase saves, one per feature

## Phase 1: Spike 1, how bailing and boarding work in vanilla

Research before building. Deliverable: [`docs/research/spike-1-bailing-boarding.md`](research/spike-1-bailing-boarding.md) (WIP: bailing mapped), covering call flow, tuning knobs, what we can hook vs. patch, and blockers for wingman bails and Raid Sector. See [DESIGN.md, Roadmap](DESIGN.md#roadmap): "Spike 1".

- [ ] Bailing (S/M): triggers, player vs. NPC attackers, what happens to the ship afterward, whether wingmen and fleets can cause and claim bails. Mapped, and wingmen causing bails is built ([capture operation](specs/capture-operation.md)). Left, both quick in-game checks ([open questions](research/spike-1-bailing-boarding.md#open-questions)):
  - [ ] A wingman with marines, set to claim, claims the prize by itself when an operation ends at "abandoned"
  - [ ] What happens to an abandoned ship nobody claims
- [ ] Boarding (L/XL): the full flow, `parameters.xml` tuning vs. engine behavior, NPC boarding, how the boarding UI talks to MD
- [ ] Adjacent: cargo drop demands, faction reactions to theft, the Yaki IFF disguise
- [x] Prior art: study Better Piracy (the original on [GitHub](https://github.com/AlbertoRota/x4-Better-piracy) and the 9.x version on Steam Workshop): its features, how it implements them, and where we differentiate. Read only; its code has no license, so nothing is copied. [research note](research/prior-art-better-piracy.md), every feature and bug catalogued
- [ ] Prior art: study the related bail and capture mods listed in the note, starting with Enhanced Bailing's 9.x variant
- [x] Find where the bail chance actually lives: `PlayerOwnedShipAttacks` in `md/notifications.xml` ([research note](research/spike-1-bailing-boarding.md)). The old `libraries/god.xml` patch was removed: 9.00 has no bail value there, and X4 merged the non-`<diff>` file as god data, logging errors on every new game
- [x] Bring back the mod's 2x bail rate as an MD diff patch on `PlayerOwnedShipAttacks` (the candidate hook in the research note): [spec](specs/bail-hook.md)
- [x] Captured ships arrive intact: no damage from the bailing pilot (hull drop, sabotage) or the claiming marine: [spec](specs/claim-no-damage.md) ([PR #18](https://github.com/ecarlste/x4-pirates-life-mod/pull/18))
- [x] Player settings for intact captures: on/off for "intact when the pilot ejects" and "intact when marines claim", from a config file: [spec](specs/capture-settings.md) ([PR #21](https://github.com/ecarlste/x4-pirates-life-mod/pull/21))
- [ ] In-game settings page through kuertee's UI Extensions (the `displayOptions_modifyOptions` hook SWI uses), optional dependency; config file stays the fallback: [spec](specs/in-game-settings.md)
- [ ] Reflect agreed findings into `DESIGN.md`, then confirm the order of the Phase 2 slices

## Phase 2: Core loop vertical slices

Each slice is demo-able and gets a video. Each one goes through: design agreed, spec written, built, tested in game, showcase save recorded, video. The order is provisional until spike 1 is done.

- [ ] 1. Wingman forces an S ship to bail; a prize crew flies it home
  - [x] Capture operation: wingmen that capture, not kill, started from a comm choice: [spec](specs/capture-operation.md) ([PR #31](https://github.com/ecarlste/x4-pirates-life-mod/pull/31))
  - [ ] Start a capture operation from the right-click/F interact menu (kuertee's UI Extensions, optional)
  - [ ] Capture hotkeys: "wing: make target bail" and "call off capture" (Chem O'Dun's Native Hotkey API on UI Extensions, optional)
  - [ ] Bail pressure in capture operations (agreed in chat 2026-10-20; spec to write):
    - In an operation, the first check rolls at vanilla's chance (no ×2). Pressure then adds +8 for every 10 s the target spends inside the bail gates, capped at 80%. Notoriety will speed it up later.
    - An operation pressure tick asks vanilla's own check every 10 s (`CapturePressureInterval`) while the player leads within about 10 km and the target is inside the gates. It expires the pilot's `$nextcapturechance` and sends vanilla's `'shouldwebail'` signal, so it's still one bail path, and it works the same under SWI's Enhanced Bailing.
    - Outside operations, bails go back to vanilla's chance (our ×2 goes away).
    - The mission readout shows the pilot's nerve.
    - Fear fades instead of vanishing (agreed 2026-10-21): if an operation ends without a capture (escaped or called off), the pressure stays on the target's pilot (`$APiratesLife_Fear` on the pilot NPC, with the time it was last set) and decays: × `CaptureFearDecayFactor` (default 0.5) per `CaptureFearDecayInterval` (default 300 s), applied when it's read, not on a timer. A new operation on that pilot starts from what's left. Capture or destruction ends it. Game tests set short intervals.
    - Built leader-agnostic: a presser profile (start factor, step, cap, interval) worked out from the operation's leader. The player is the only case for now; later, notoriety raises the player's numbers, and Raid Sector wings use the same logic at lower numbers.
  - [ ] Wing-level stop line: the operation adds up the laser DPS of the wingmen that are firing and sets one shield-HP stop line for all of them, instead of each wingman's own 1.5 s margin. If that line is above the 20% bail gate, only the lightest-armed wingmen suppress while the rest hold.
  - [ ] Prize crew flies a captured ship home
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

- [ ] Capture operations: wingmen prefer shield-heavy weapons (ion), from a profile list, since scripts can't read a weapon's damage type
- [ ] Recognisable pirate: a unique ship or paint job lets pilots know a notorious player without a hail, so they bail more readily outside capture operations
- [ ] Capture operations: drop the wing ×4 bail chance once the pressure tick lands, since the tick carries the pressure (simpler, closer to vanilla)
- [ ] Capture operations: scale the wingmen's stop margin with distance to the target (more shots in flight from farther away), if play shows it matters; scripts can't read projectile speed
- [ ] PSScriptAnalyzer and shellcheck in PR CI as well as at release
- [ ] Game tests through Egosoft's NoSteam executable: research and PoC (own arguments, no Steam prompt or session limit; needs its own profile folder): [notes](research/automated-game-testing.md#egosofts-nosteam-executable)
- [ ] Game-test report on the PR: compare the PR's run with the latest run on `main` (newly failing, newly passing, new tests): [notes](research/automated-game-testing.md#comparing-a-prs-run-with-main)
- [ ] Game tests in CI before inviting contributors (test machine, dedicated Steam account, approval gate, post-merge gate, automated release): [notes](research/automated-game-testing.md#cicd)
- [ ] Refitting captured ships without legit factions ([research note](research/pirate-refitting.md#design-ideas)). Vanilla gives a pirate only general-use gear at the Vigor wharf early on, so:
  - [ ] Prize-to-prize transfer: move a prize's weapons, turrets and shields onto another ship (`apply_loadout`), stripping the source
  - [ ] Salvage stash: strip prizes into a per-ware parts stash (MD data); refit empty slots from it at a pirate contact and later the hideout (`generate_loadout` limited to stash wares)
  - [ ] Fences buy salvaged gear and sell stolen gear, military included, priced by notoriety instead of licence rep (part of slice 3)
  - [ ] Bounty hunter loot: blueprint crates and stash parts from destroyed hunters (part of slice 6)
  - [ ] Raid a faction, arm from its enemies: delivering booty taken from a faction to the pirate factions that hate it raises rep with them, and unlocks "pirate-modified" versions of the target's gear (new items on the same models, with stats traded off for raiding, made by a generator script that can also run on weapon mods) while the player stays low with the target. Equipment on turned-in ships earns salvage credits for its slot size, scaled by its price; the player spends them to unlock any pirated item of that size, and to buy blueprints of unlocked items (and of the equipment-dock modules) from the same vendor, priced like vanilla: blueprints at about 10× an item's unlock cost. Item unlock cost and blueprint cost are separate player multipliers. Works for modded weapons with no onboarding ([research note](research/pirate-refitting.md#raid-a-faction-arm-from-its-enemies))
  - [ ] Profile maps, changeable by other mods (MD diff or a registration signal): hunted faction → pirate factions that reward raiding it, and pirate (currency) faction → vendor stations by size, so every pirate faction's gear can be routed to whichever stations can fit it ([research note](research/pirate-refitting.md#profile-maps-who-rewards-raids-and-where-gear-is-sold))
  - [ ] Vanilla profile: which factions count as pirate suppliers, and maybe diff-patch an S/M fitting module or extra ware owners onto a pirate station
