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
- [ ] Linting and formatting standards for every language we use (bash, PowerShell, Python, Lua, MD/AI script and library XML, Markdown, YAML): pick a linter and a formatter for each, agree the rules, and wire them into the commit hook, `make release` and CI. Its own session; the two items below become part of it
- [ ] Autoformat scripts on commit: shfmt and PSScriptAnalyzer's formatter, through a pre-commit hook enabled by `make setup`
- [ ] `make release`: lint (shellcheck, PSScriptAnalyzer default rules, format check), run the tests, build the release zip from a clean `origin/main`, and write the release checklist (`tools/test_plan_docs.py --checklist dist/release-checklist.md`) next to it in `dist/`; drop linting from `make test` and PR CI
- [x] Repo README: what the mod is, prerequisites, setup, deploy, test, coming back after a break ([PR #5](https://github.com/ecarlste/x4-pirates-life-mod/pull/5))

**In-game dev tooling** (from [DESIGN.md, Roadmap](DESIGN.md#roadmap): "Dev tooling, early")

- [x] Smoke test proving the mod runs in game, and the first real `make deploy` ([PR #11](https://github.com/ecarlste/x4-pirates-life-mod/pull/11)): an MD script that writes to `debuglog.txt` (`debug_text`) and shows an on-screen notification (`show_notification`) on `event_game_started` / `event_game_loaded`, plus a log line when a ship is abandoned (`event_object_abandoned`) or attacked (`event_object_attacked`)
- [ ] Showcase/test gamestart (the game tests' gamestart below covers testing; a showcase start is still to do)
- [x] Automated in-game regression tests: a dev-only test extension (test gamestart, MD tests, Lua autostart) and a runner that starts X4, reads the results from `debuglog.txt` and reports PASS/FAIL (`make game-test`): [research note](research/automated-game-testing.md). Proof of concept built with tests for the bail hook and intact captures ([PR #20](https://github.com/ecarlste/x4-pirates-life-mod/pull/20)); first in-game run: 3 of 3 pass ([PR #28](https://github.com/ecarlste/x4-pirates-life-mod/pull/28))
- [x] Game-test plan in Gherkin: one `.feature` file per feature in `tests/game/features/`, scenarios tagged with the game test that covers them or `@pending`, checked against the tests by `make test`
- [x] Game tests for the capture settings: each intact flag off gives vanilla damage ([PR #29](https://github.com/ecarlste/x4-pirates-life-mod/pull/29))
- [x] `make game-test-report`: post the last game-test report to the branch's PR as a comment and a `game-tests` commit status, only when it's for the PR's latest commit with nothing uncommitted ([PR #30](https://github.com/ecarlste/x4-pirates-life-mod/pull/30))
- [x] `@manual` scenarios in the game-test plan, checked by hand at every release (separate from `@pending`, which should get a game test), and `tools/manual-checklist.py` to turn them into a Markdown checklist ([PR #40](https://github.com/ecarlste/x4-pirates-life-mod/pull/40))
- [x] Lua checks in `make test` and CI: luacheck (lint and syntax) on `ui/`, the test extension's Lua and the Lua tests, and LuaUnit unit tests for the settings page's logic under LuaJIT, with X4's functions stubbed (`tests/lua/`). LuaUnit instead of busted, which needs a C compiler for its dependencies ([PR #44](https://github.com/ecarlste/x4-pirates-life-mod/pull/44))
- [x] Test pyramid and coverage policy in `docs/PROJECT.md`; unit tests count as coverage in the test plan (tagged by name), and a readable test plan generated into `docs/test-plan/` by `make test-plan`, warned about by `make test` and checked in CI. 9 manual settings-profile scenarios moved to unit and UI tests ([PR #45](https://github.com/ecarlste/x4-pirates-life-mod/pull/45))
- [x] Release checklist from the same generator: every `@manual` and `@pending` scenario, with its steps (`tools/test_plan_docs.py --checklist <file>`), replacing `tools/manual-checklist.py` ([PR #46](https://github.com/ecarlste/x4-pirates-life-mod/pull/46))
- [x] Python unit tests for `tools/` with `unittest` in `tests/python/`, run by `make test` and CI's bats jobs; Python tools renamed with underscores so the tests import them ([PR #47](https://github.com/ecarlste/x4-pirates-life-mod/pull/47))
- [x] Fast local `make test` (about 4 min to about 30 s): Pester on PowerShell 7 in WSL, one process per test file in parallel and overlapped with the other suites, slow Pester files split by topic, bats files in parallel with GNU parallel ([PR #50](https://github.com/ecarlste/x4-pirates-life-mod/pull/50))
- [x] CI tests each script where it runs: bats, shellcheck and Lua on Linux, Pester on Windows (5.1 and 7); macOS jobs and Pester on Linux and macOS dropped ([PR #72](https://github.com/ecarlste/x4-pirates-life-mod/pull/72))
- [x] Faster game tests (2 min 50 s to about 1 min 30 s): the test start in a tutorial's one-sector galaxy (since PR #64 the docking tutorial's, for its map-placed wharf), no ship calls in (the player's global standing orders don't ask), SETA checked in the report, per-phase timings in the report, shorter fixed waits ([PR #51](https://github.com/ecarlste/x4-pirates-life-mod/pull/51))
- [ ] Test galaxy with a second sector joined by a gate (agreed 2026-10-27): our own small galaxy macro in the test extension, reusing the docking tutorial's wharf cluster (its map-placed wharf is the booty tests' Vigor wharf; stations spawned with `create_station` only let their owner dock, [research note](research/booty.md#to-verify-in-game)) plus a second cluster. Build it with the first test that needs it: the booty pilot going to another sector (`@manual` now), the handover order's nearest station by gates, capture operations following a target through a gate, later Raid Sector
- [ ] Fix the flaky `capture_wing_holds_fire` game test: about one run in three or four the wingman never breaks the target's hull below 75% ("hull only got to 80% in 180s, 0 s under 75%"; seen 2026-10-27 on the pirated-ships and booty-order PRs, passing on the rerun each time). The break phase, not the hold that PR #61 changed. Find out whether the wingman isn't landing hits (dogfight range, shields recharging faster than two pulse lasers) or isn't attacking at all, then make the test deterministic
- [ ] Make the game tests pass with X4 in the background (Erik, 2026-10-28; not urgent): with the window unfocused, `capture_wing_holds_fire` and `booty_order_hands_over` fail every run, on `main` too, and the tests take about twice as long (1 min 51 s against 51 s). The likely cause: the run's 6× time warp at the lower frame rate X4 gets in the background, so each frame covers more game time and ships steer, fight and dock worse. Options: less time warp or more time for those tests, or the runner brings X4's window to the front (or warns when it isn't). May also explain some of the flaky test above
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
- [x] In-game settings page through kuertee's UI Extensions (the `displayOptions_modifyOptions` hook SWI uses), optional dependency; config file stays the fallback: [spec](specs/in-game-settings.md) ([PR #37](https://github.com/ecarlste/x4-pirates-life-mod/pull/37))
- [x] Named settings profiles on the settings page: save the current settings under a name, load any profile into any save from a dropdown, choose the profile new games start from, delete profiles; replaces "my defaults": [spec](specs/settings-profiles.md) ([PR #39](https://github.com/ecarlste/x4-pirates-life-mod/pull/39))
- [x] Settings profiles: a game is on a profile (Default or a saved one) and follows it until a setting is changed ("Hard mode *", "Save changes to …"); saved changes become "None (custom settings)" on load; no reset row: [spec](specs/settings-profiles.md), [flows](specs/settings-profiles-flows.md) ([PR #42](https://github.com/ecarlste/x4-pirates-life-mod/pull/42), [PR #43](https://github.com/ecarlste/x4-pirates-life-mod/pull/43), [PR #48](https://github.com/ecarlste/x4-pirates-life-mod/pull/48), [PR #49](https://github.com/ecarlste/x4-pirates-life-mod/pull/49))
- [ ] Reflect agreed findings into `DESIGN.md`, then confirm the order of the Phase 2 slices

## Phase 2: Core loop vertical slices

Each slice is demo-able and gets a video. Each one goes through: design agreed, spec written, built, tested in game, showcase save recorded, video. The order is provisional until spike 1 is done.

- [ ] 1. Wingman forces an S ship to bail; a prize crew flies it home
  - [x] Capture operation: wingmen that capture, not kill, started from a comm choice: [spec](specs/capture-operation.md) ([PR #31](https://github.com/ecarlste/x4-pirates-life-mod/pull/31))
  - [ ] Bug: overlapping capture operations (found in Erik's game, 2026-10-27, three operations started from comms while paused). Each start takes the whole wing, so the earlier operations lose their wingmen but still list them as members (so their hits still get the ×4 wing bonus). When the last operation ends, the wingmen go back to their defence assignment and attack the other prizes with vanilla's attack: no hold line, missiles allowed. One of Erik's prizes only survived because it bailed on its first check. Tentative fix, to agree before a spec: a queue, for players on vanilla and Tides of Avarice alone (no UI mod). Operations started while one runs wait their turn in the order they were hailed, and when one ends the wing moves on to the next instead of going back to formation; the readout shows what's next. A way to pick several targets with UI Extensions can come later.
  - [ ] Start a capture operation from the right-click/F interact menu (kuertee's UI Extensions, optional)
  - [ ] Capture hotkeys: "wing: make target bail" and "call off capture" (Chem O'Dun's Native Hotkey API on UI Extensions, optional)
  - [ ] Bail pressure in capture operations (agreed in chat 2026-10-20; spec to write):
    - In an operation, the first check rolls at vanilla's chance (no ×2). Pressure then adds +8 for every 10 s the target spends inside the bail gates, capped at 80%. Notoriety will speed it up later.
    - An operation pressure tick asks vanilla's own check every 10 s (`CapturePressureInterval`) while the player leads within about 10 km and the target is inside the gates. It expires the pilot's `$nextcapturechance` and sends vanilla's `'shouldwebail'` signal, so it's still one bail path, and it works the same under SWI's Enhanced Bailing.
    - Outside operations, bails go back to vanilla's chance (our ×2 goes away).
    - The mission readout shows the pilot's nerve.
    - Fear fades instead of vanishing (agreed 2026-10-21): if an operation ends without a capture (escaped or called off), the pressure stays on the target's pilot (`$APiratesLife_Fear` on the pilot NPC, with the time it was last set) and decays: × `CaptureFearDecayFactor` (default 0.5) per `CaptureFearDecayInterval` (default 300 s), applied when it's read, not on a timer. A new operation on that pilot starts from what's left. Capture or destruction ends it. Game tests set short intervals.
    - Settings (after the in-game settings page lands): the pressure numbers (step, cap, interval, fear decay) as config values; which of them go on the settings page is decided then, per the page's [rule](specs/in-game-settings.md#design) that only player choices go there.
    - Built leader-agnostic: a presser profile (start factor, step, cap, interval) worked out from the operation's leader. The player is the only case for now; later, notoriety raises the player's numbers, and Raid Sector wings use the same logic at lower numbers.
  - [ ] Wing-level stop line: the operation adds up the laser DPS of the wingmen that are firing and sets one shield-HP stop line for all of them, instead of each wingman's own 1.5 s margin. If that line is above the 20% bail gate, only the lightest-armed wingmen suppress while the rest hold.
  - [ ] Prize crew flies a captured ship home
  - [x] Capture metrics: one summary line per capture (operation or plain attack) when it ends, with the target's class, size, macro, owner, crew, pilot skill and morale, the attackers and their classes, time to the bail gates, checks, successes, total time and outcome; plain attacks on capturable ships tracked from the first player hit; a `tools/` script that turns `debuglog.txt` files into a CSV. Feeds the booty level thresholds ([research note](research/booty.md#capture-times)) ([spec](specs/capture-metrics.md)), [PR #53](https://github.com/ecarlste/x4-pirates-life-mod/pull/53)
- [ ] 2. Notoriety and heat v1, with bail chance tied to notoriety
- [ ] 3. Fencing and hot-goods pricing at pirate docks
  - [ ] Booty v1 (tentative design agreed 2026-10-26, refined 2026-10-27, [DESIGN.md](DESIGN.md#booty-and-pirate-standing); [spec](specs/booty.md)): pirate groups from the profile (factions sharing a wharf and shipyard), each with one currency, standing ladder, tastes and unlock list, with only the Vigor Syndicate in v1; unlocks as hidden research, gating our variants instead of licences (rep still decides who can dock and buy; unlocks are kept for good, so own-wharf building works even at war); variants from a profile list, made by a generator kept in sync by a test, starting small; unlocks bought in a conversation with the group's representative; hand over a prize with an order or a talk with the station manager, at a group station that can take its size, handled like a sale there; credits are a vanilla sale minus a fence cut that falls with standing; booty from the ship's total value with a stolen bonus for pirated ships (taken by boarding or bailing in combat with the player's ships while the mod runs) and the group's tastes by maker race; many standing levels opening M, L, XL turn-ins, unlock tiers and a lower cut; standing only goes up for now; the pilot moves to a free marine slot at handover. Data and open checks: [research note](research/booty.md); the in-game `.value` checks and the capture-metrics `@manual` CSV check are done with it ([list](research/booty.md#to-verify-in-game))
    - [x] Spike: make an unlocked ship or item show up in a group station's build and equipment menus for this player only, like a licence. Answer: one hidden research ware per unlock, proven in game at the Vigor wharf ([research note](research/booty.md#proof-of-concept-in-game-2026-10-27))
    - [x] Pirated-ship mark: ships the player takes by boarding or bailing in combat with any of their ships are marked pirated; everything else counts as a donation ([spec](specs/pirated-ships.md)), [PR #60](https://github.com/ecarlste/x4-pirates-life-mod/pull/60)
    - [x] Handover by conversation at Vigor stations, the Lua sale, groups, levels, fence cut, booty and standing, the booty settings: [PR #63](https://github.com/ecarlste/x4-pirates-life-mod/pull/63)
    - [x] Handover order, and the pilot's move to a free marine slot: [PR #64](https://github.com/ecarlste/x4-pirates-life-mod/pull/64)
    - [x] Variants: the list, the generator and its sync check, the first set's ships: [PR #68](https://github.com/ecarlste/x4-pirates-life-mod/pull/68)
    - [x] Variants: the first set's gear (pirate combat, all-round and travel engines, quick-recharge shields, the Stripper on the ion blaster, the pirate EMP missile): [PR #69](https://github.com/ecarlste/x4-pirates-life-mod/pull/69)
    - [x] Variants: the Stripper turret, the first pirate turret, on the Teladi M muon blaster turret (Erik, 2026-10-28): [PR #70](https://github.com/ecarlste/x4-pirates-life-mod/pull/70)
    - [x] Variants: one manifest for the generator's stamp and file hashes, so regenerating only changes files whose content changed (Erik, 2026-10-28): [PR #75](https://github.com/ecarlste/x4-pirates-life-mod/pull/75)
    - [ ] Pirate paint for variants (Erik, 2026-10-27): a pirate paint mod, data only, on vanilla's patterns first (`libraries/paintmods.xml`, `libraries/themes.xml`), and a way for a variant to wear it by default (a spike: player ships take the player's theme); later our own pattern texture, generated by a Python script (Pillow, or a tiling image model) and converted to DDS
    - [ ] Unlocks granted with the level (Erik, 2026-10-28: standing unlocks buying, booty buys blueprints; design: [PR #71](https://github.com/ecarlste/x4-pirates-life-mod/pull/71)): [PR #74](https://github.com/ecarlste/x4-pirates-life-mod/pull/74)
    - [ ] Blueprints bought with booty
    - [x] Variants: Mk2 and Mk3 gear on the level table ([DESIGN.md](DESIGN.md#booty-and-pirate-standing), Erik, 2026-10-28): S engines, shield and Stripper Mk2 at 5, S engines and shield Mk3 at 7, M engines and shield Mk2 at 9, M Stripper Mk2 at 10, M engines Mk3 at 12; L shields Mk1 at 9, Mk2 at 11 and Mk3 at 14; M shield Mk3 at 12; XL shields Mk1 at 16 and Mk2 at 18. Marks beyond the base game's (M and L shield Mk3, XL shield Mk2) need the generator to take a mark and stat steps from the list. List entries and `make variants`, after the unlocks PR; design: [PR #73](https://github.com/ecarlste/x4-pirates-life-mod/pull/73), [PR #77](https://github.com/ecarlste/x4-pirates-life-mod/pull/77)
    - [ ] Pirate lord window (after v1): with kuertee's UI Extensions, a full window for the level table, blueprints, standing and booty in place of the conversation, and a README line teasing the landlubbers who don't install it
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

- [ ] A setting to turn off the pirate marks beyond the base game's (M and L shield Mk3, XL shield Mk2), if players without the DLCs find them overpowered (Erik, 2026-10-28)
- [ ] More to buy with booty (Erik, 2026-10-28): the equipment mod parts vanilla only drops at random, and pilots and crew far better than a station's
- [ ] Booty buys early access: an unlock one or two levels ahead of the player's standing, at a premium, if booty feels pointless before the player owns a wharf (Erik, 2026-10-28: probably not needed, as the standing gain setting covers impatience)
- [ ] Settings profiles: mark profiles made during manual (UAT) testing so the game-test cleanup removes them. Options: a deploy-time switch (`--set MarkAsTest=1`, everything created while deployed gets the `test` mark), a "mark as test" row in the dev menu, or a UAT game start in the test extension (needs a switch so it doesn't start the automated tests)
- [ ] Capture operations: wingmen prefer shield-heavy weapons (ion), from a profile list, since scripts can't read a weapon's damage type
- [ ] Recognisable pirate: a unique ship or paint job lets pilots know a notorious player without a hail, so they bail more readily outside capture operations
- [ ] Capture operations: drop the wing ×4 bail chance once the pressure tick lands, since the tick carries the pressure (simpler, closer to vanilla)
- [ ] Capture operations: scale the wingmen's stop margin with distance to the target (more shots in flight from farther away), if play shows it matters; scripts can't read projectile speed
- [ ] PSScriptAnalyzer and shellcheck in PR CI as well as at release
- [ ] Game tests through Egosoft's NoSteam executable: research and PoC (own arguments, no Steam prompt or session limit; needs its own profile folder): [notes](research/automated-game-testing.md#egosofts-nosteam-executable)
- [ ] Game-test report on the PR: compare the PR's run with the latest run on `main` (newly failing, newly passing, new tests): [notes](research/automated-game-testing.md#comparing-a-prs-run-with-main)
- [ ] Game tests in CI before inviting contributors. Goal: releases with no manual UAT, the by-hand count in `docs/test-plan/` at zero (test machine, dedicated Steam account, approval gate, post-merge gate, automated release whose approval gate, a GitHub Environment needing Erik's approval, shows the manual release checklist in the job summary): [notes](research/automated-game-testing.md#cicd)
- [ ] Pirate group missions: missions from a group, gated by standing, like SWI's bounty-hunter missions but from the pirate side; tips on targets (a rich convoy, a lightly guarded L ship) ([research note](research/booty.md#still-iterating))
- [ ] Standing perks beyond unlocks: services at a group's stations (repairs, crew and marines), and protection from its ships (vanilla relations may be locked, so research first)
- [ ] Losing standing: betrayal (attacking a group's ships, selling out a drop), handing ships to a rival group, neglect
- [ ] Notoriety favours: at random, a group adds extra money to a handover to buy the favour of a famous pirate
- [ ] What pirates do with handed-over ships beyond a sale: the group flies them (its fleet really grows; needs a spike on ownership changes, orders and a cap), or strips them for parts
- [ ] Booty for cargo: turn in cargo for booty, mostly mission cargo, and high-value cargo a target is made to jettison for a big payout; keeps cargo valuable on some pirate builds ([research note](research/pirate-variants.md#ideas-not-part-of-the-proposal))
- [ ] A disabler for L/XL captures: a weapon or missile that knocks out turrets and engines without hurting the hull; vanilla has no damage type for it, so a spike first ([research note](research/pirate-variants.md#ideas-not-part-of-the-proposal))
- [ ] More booty groups after Vigor: the Riptide Rakers as the honorable path (Vigor the notorious one), the Yaki wharf for S/M; SCA has no wharf or shipyard ([research note](research/booty.md#still-iterating))
- [ ] Earn past a locked relation (e.g. SCA's −5) through piracy: a standing reward or quest line that unlocks, raises and relocks it, as vanilla's terraforming milestone does
- [ ] Pirate lord: found your own pirate faction (first), take over an existing group (later), joint operations with a group on large targets at high standing and notoriety. Deep dive once playtesting reaches that stage
- [ ] Refitting captured ships without legit factions ([research note](research/pirate-refitting.md#design-ideas)). Vanilla gives a pirate only general-use gear at the Vigor wharf early on, so:
  - [ ] Prize-to-prize transfer: move a prize's weapons, turrets and shields onto another ship (`apply_loadout`), stripping the source
  - [ ] Salvage stash: strip prizes into a per-ware parts stash (MD data); refit empty slots from it at a pirate contact and later the hideout (`generate_loadout` limited to stash wares)
  - [ ] Fences buy salvaged gear and sell stolen gear, military included, priced by notoriety instead of licence rep (part of slice 3)
  - [ ] Bounty hunter loot: blueprint crates and stash parts from destroyed hunters (part of slice 6)
  - [ ] Raid a faction, arm from its enemies: delivering booty taken from a faction to the pirate factions that hate it raises rep with them, and unlocks "pirate-modified" versions of the target's gear (new items on the same models, with stats traded off for raiding, made by a generator script that can also run on weapon mods) while the player stays low with the target. Equipment on turned-in ships earns salvage credits for its slot size, scaled by its price; the player spends them to unlock any pirated item of that size, and to buy blueprints of unlocked items (and of the equipment-dock modules) from the same vendor, priced like vanilla: blueprints at about 10× an item's unlock cost. Item unlock cost and blueprint cost are separate player multipliers. Works for modded weapons with no onboarding ([research note](research/pirate-refitting.md#raid-a-faction-arm-from-its-enemies))
  - [ ] Profile maps, changeable by other mods (MD diff or a registration signal): hunted faction → pirate factions that reward raiding it, and pirate (currency) faction → vendor stations by size, so every pirate faction's gear can be routed to whichever stations can fit it ([research note](research/pirate-refitting.md#profile-maps-who-rewards-raids-and-where-gear-is-sold))
  - [ ] Vanilla profile: which factions count as pirate suppliers, and maybe diff-patch an S/M fitting module or extra ware owners onto a pirate station
