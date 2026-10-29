# Automated in-game testing

**Status: WIP, working (2026-10-20).** `make game-test` runs in the real game: all 5 tests pass in about 2½ minutes from command to report, with no clicks once Steam's one-time launch prompt has been accepted (see [first runs](#first-runs-in-game)). Still open: the questions at the end.

Goal: Cypress/Playwright-style regression tests that play a short, controlled scenario in the real game and report PASS/FAIL, run locally on Erik's Windows machine with one command.

## Summary

- **It can be done with no clicks and no screen reading.** X4 already has everything we need. An extension's Lua can start a gamestart from the main menu (`NewGame(id)`). MD can set up scenarios, read the results, log them, and quit the game (`quit_to_desktop`). An external script launches X4 and reads `debuglog.txt`.
- **Recommended architecture:** a dev-only **test extension** (its own gamestart, MD tests, a few lines of Lua for the autostart) plus a **PowerShell runner** that installs the extension, starts X4, follows the log until the run finishes or times out, removes the extension and writes a JUnit report. Built in this PR as a proof of concept: `make game-test`.
- **Deterministic bails without combat:** a test signals vanilla's bail check directly and switches on vanilla's own `$testcheat`. That skips the gates, the 30 s cooldown and the roll.
- **Local only.** GitHub's hosted runners can't run X4 (no GPU, Steam or licence). CI keeps testing the runner's logic with Pester; the game tests run on Erik's PC (`make game-test`), maybe later on a self-hosted runner.
- **Screen automation (SendInput, screenshots, OCR)** only for UI we can't drive through Lua, and only as a thin layer. Nothing needs it yet.

## Findings

### Starting a test game without clicks

- **No documented command-line option loads a save or starts a gamestart.** `X4.exe` contains the strings `load` and `mpar` in what looks like command-line parsing code, plus the messages "Failed to initialize the module: "%s" with parameters '%s'" and "The specified module "%s" is not registered. Defaulting to startmenu". So there may be an undocumented way to start a module. Unverified, and the design doesn't need it.
- **Lua can do it.** Vanilla's menus use the globals `NewGame(gamestartid)` (`ui/addons/ego_gameoptions/gameoptions.lua`, e.g. ~line 8099), `LoadGame(filename)` (~line 2963) and `QuitGame()` (~line 8125). The main menu is itself a module named `startmenu` (`NewGame("startmenu")` returns to it). Lua can read the current one with `C.GetGameStartName()`.
- **Vanilla also has a `loadSave` Lua event** (`gameoptions.lua:408`, `menu.loadSaveCallback`) that loads a named save. A fallback if starting from a gamestart turns out not to work, at the cost of keeping test saves up to date with each game version.
- **An extension's Lua loads from its `ui.xml`**, as SWI does ([UI research](third-party-ui-apis.md#how-swi-builds-its-ui)). The test extension's Lua waits 3 s in the main menu, then calls `NewGame("apirateslife_test")`. The UI is rebuilt for every module, so in the test game it sees a different module name and does nothing.

### A fixed test gamestart

- **Gamestarts can switch off the living universe:** `<universe><jobs enabled="false"/><god enabled="false"/></universe>` (vanilla's debug start `thevoid`). No god means no stations; no jobs means no NPC traffic. Every test then spawns exactly what it needs, and runs start the same each time.
- **Vanilla ships debug test starts** (`group="100"`, `debug="true"`): `test_smallship`, `test_squadron`, `test_battle`, `thevoid` (an empty `blackgalaxy_macro`), `testbed1`, `default`. Ours copies `test_smallship`'s spot in Argon Prime, without `debug="true"`, so it also shows in the New Game menu for starting it by hand.
- **The test start uses the tutorials' empty galaxy** (`basegame_map_tutorial_default_empty_galaxy_macro`, one cluster with one sector), not the full universe. Measured 2026-10-26: loading to the first test went from 1 min 32 s to 28 s, and a whole run from 2 min 50 s to about 1 min 30 s. The about 380 vanilla "Error in MD cue" lines (DLC and story setup cues looking for stations god never built) are gone too. Tests spawn everything they need in `player.sector`, so nothing depended on Argon Prime.
- **Ships calling in stop SETA:** the player's global standing orders (Player Info > Global orders) can "ask" before responding to six signals (`attacked`, `foundabandonedship`, `foundlockbox`, `piratehalt`, `policefoundcontraband`, `policehalt`); a ship that asks opens a conversation, and SETA stops. MD can only set "ask" per ship (`set_object_signal_response ... ask="false"`); the global orders are set from Lua with `C.SetDefaultResponseToSignalForFaction2(response, ask, signal, "player", purpose)` for the purposes `""`, `"fight"` and `"auxiliary"`, as vanilla's menu does. The test extension's Lua turns "ask" off for all 18 at the start of a run, keeping each response. With that, SETA stayed on for a whole run (`player.timewarp.active`; the harness's `KeepSeta` cue logs and fixes any drop, and the report says whether SETA held).
- **The `nosave` tag** (used by tutorials) keeps test games out of the save list.
- **MD knows which gamestart it's in:** `player.module` is the gamestart ID (vanilla compares it with e.g. `'custom_creative'`). That's the guard for test code.
- **`md.Setup.GameStart` also fires for the main menu's background game**, which explains the double fire noted in [spike 1](spike-1-bailing-boarding.md#extension-loading). It's another reason to check `player.module`.

### Time acceleration and quitting from MD

From `libraries/md.xsd` and `common.xsd` (9.00):

| Action | What it does |
| --- | --- |
| `toggle_timewarp` | Toggles SETA. Needs SETA (`inv_timewarp`) in the player's inventory and SETA's own conditions (e.g. not in a conversation; no enemies nearby, as in normal play) |
| `set_timewarp_factor factor="…"` | Game seconds per real second while SETA is on, clamped to 0.1–6.0 |
| `quit_to_desktop` | Ends the game process: how a run finishes |
| `quit_to_startmenu`, `quit_to_load_latest_save` | Back to the menu, or reload the latest save |
| `trigger_autosave` | Saves, e.g. to keep the state when a test fails |

So 6x is the most MD can speed things up. Tests should avoid waiting for travel or combat at all (below).

### Making scenarios deterministic

- **Bail checks without combat.** A ship's AI asks for a bail check with `signal_objects object="player.galaxy" param="attacker" param2="target" param3="'shouldwebail'"` (`aiscripts/interrupt.attacked.xml`). A test can send the same signal, and it reaches `PlayerOwnedShipAttacks` exactly like a real attack.
- **Vanilla's `$testcheat`** (`md/notifications.xml`, `PlayerOwnedShipAttacks`) skips the hull and shield gates and the cooldown, and makes the roll 100%. It's a variable of each cue instance, so only a patch can set it. The test extension's own `md/notifications.xml` patch sets it while `global.$APiratesLifeTest_ForceBail` is on. The mod's own code stays free of test switches, and the mod's hook still runs before the roll.
- **The pilot bails on the first check when the target has no crew** (`people fillpercent 0`): vanilla bails the pilot once the batch covers all remaining crew, as long as the attacker is player-owned.
- **Pure logic can be unit tested** by calling our libraries directly (`run_actions ref="md.APiratesLife_Bail.AdjustEjectChance"`), with no scenario at all.
- **Damage checks need a skilled pilot or marine:** vanilla's bail and claim damage scale with (100 − skill). The pilot-bail test fails if the pilot rolled 0 skill, since it would then prove nothing.
- **Claims need real AI:** a player-owned ship set to `foundabandonedship` = `claim` (`set_object_signal_response`) with marines and a non-priority order (`aiscripts/interrupt.foundabandonedship.xml`) notices the ownerless ship on its next scan and sends a marine (`move.claim`). That's slower and less certain than the bail tests, hence a 180 s timeout.

### Logs

- `debug_text` lines go to `debuglog.txt` (under `[Scripts]`, with the cue as context). Lua's only logger there is `DebugError`, which shows as `[=ERROR=]` even for normal messages.
- The runner deletes the old log before starting, so it can't report a previous run. It reads the log while the game still has it open (shared read).

## The proof of concept

| Path | What |
| --- | --- |
| `tests/game/apirateslife_tests/` | The test extension (ID `apirateslife_tests`, depends on `apirateslife`). Never shipped: it's outside `deploy.include` |
| `…/libraries/gamestarts.xml` | Diff adding the `apirateslife_test` gamestart: Argon Prime, god and jobs off, a scout with SETA, `nosave` |
| `…/ui.xml`, `…/ui/apirateslife_tests_autostart.lua` | Starts the test gamestart 3 s into the main menu |
| `…/md/apirateslife_tests.xml` | The harness, shared helpers (`SpawnBailPair`, `SpawnClaimPair`, `EquipmentCount`, `ForceBail`) and five tests, run one after another |
| `…/md/notifications.xml` | Test-only patch that switches on `$testcheat` |
| `tools/run-game-tests.ps1` | The runner |
| `tests/GameTests.Tests.ps1` | Pester tests for the runner (log parsing, report, whole runs against a fake game), run by `make test` and CI |
| `Makefile` | `make game-test`: deploys the working tree, then runs the runner through Windows PowerShell |

**Tests:**

| Test | Covers |
| --- | --- |
| `eject_chance_doubled` | `AdjustEjectChance`: 0→0, 10→20, 30→60, 50→100, 70→100 |
| `pilot_bail_intact` | Intact on eject on: a forced pilot bail: our `Bailed` signal fires with `$pilot`, the ship is ownerless, hull and equipment unchanged ([bail hook](../specs/bail-hook.md), [capture without damage](../specs/claim-no-damage.md)) |
| `claim_intact` | A marine claims an ownerless fighter: it becomes the player's with hull and equipment unchanged. The "visible" attention level only |
| `pilot_bail_vanilla_when_off` | With intact on eject off, a forced pilot bail does vanilla's damage exactly: hull to about (100 − pilot skill)%, and min(non-mandatory parts, skill ÷ 10) parts sabotaged |
| `claim_vanilla_when_off` | With intact on claim off, the claimed fighter's hull drops to vanilla's max(marine skill, 70)%. Equipment isn't checked: vanilla destroys each part only by chance |
| `capture_wing_full_chance` | Bail hook in a capture operation: members ×4×2, non-members ×2, setting off ×2; last chance recorded ([capture operation](../specs/capture-operation.md)) |
| `capture_start_and_destroyed` | `Start` accepts a capturable fighter, refuses a player-owned ship and a second operation; destroying the target ends it as destroyed |
| `capture_abandoned` | A forced pilot bail ends the operation as abandoned and clears its state |
| `capture_escape_waits_for_engagement` | An operation started on a target 20 km away is still running 40 s later: the escape timer waits until someone has been within 15 km |
| `capture_escaped` | Once engaged, a target warped 25 km away ends the operation as escaped after 30 s |
| `capture_wing_holds_fire` | Real combat: a pulse-laser wingman (fixed loadout) breaks a worn-down fighter (80% hull, shields held at 0 until it is under 75%) to under 75% and keeps it there 30 s, never more than 20 points under the gate or below the 35% floor (target made uncapturable after the start so no bail ends it) |

**Log protocol** (every line starts with `[apirateslife-test]`): `RUN START <n> tests`, `PASS <name>: <detail>` / `FAIL <name>: <detail>`, `DONE passed=<n> failed=<n>`. A run fails if any test fails, fewer than `<n>` results arrive, `DONE` never comes (game exited or timed out), or the log has errors mentioning the mod (signature warnings excluded).

**Validation so far:** every XML file validates against the 9.00 XSDs (`md.xsd`, and `gamestarts.xsd` with the diff applied); vanilla `notifications.xml` validates against `md.xsd` with both our patches applied; the `$testcheat` selector matches exactly one element. The runner's Pester tests pass in Windows PowerShell 5.1.

### A run

```
make game-test        # or: .\deploy.ps1 -WorkingTree; .\tools\run-game-tests.ps1
```

1. The runner checks the mod is deployed and X4 isn't running, copies the test extension into `extensions\apirateslife_tests`, and moves the old `debuglog.txt` to `debuglog.previous.txt`.
2. It asks Steam to start X4 (`steam://rungameid/392160`), so the game gets the Steam launch options, which must include `-logfile debuglog.txt` (see [PROJECT.md, Paths](../PROJECT.md#paths-eriks-machine)), and waits up to 120 s for the `X4` process.
3. The Lua autostart starts the test gamestart; MD runs the tests and quits the game.
4. The runner prints each result as it arrives, closes the game if it's still running after `DONE` (30 s grace) or at the timeout (900 s), removes the test extension, writes `tests/game/results.xml` (JUnit) and `tests/game/report.md`, and exits 0 or 1.

### Posting a run to the PR

```
make game-test          # on the PR's latest commit, with everything committed and pushed
make game-test-report   # ARGS=--dry-run to check and preview without posting
```

- **The report** (`tests/game/report.md`) names the commit, branch, X4 version (from the log's "Starting new game" line), duration and start time, with a row per test, any run problems, and any errors from the mod. `make game-test` passes the commit, branch and dirty state from WSL's git; run directly, the runner asks git itself.
- **A hidden first line** carries what the poster checks: `<!-- apirateslife-game-tests commit=<sha> dirty=<true|false> result=<pass|fail> passed=<n> total=<n> -->`.
- **`tools/post-game-test-report.sh`** (bash and `gh`, so WSL) posts only when the run had no uncommitted changes, the report's commit is `HEAD`, and `HEAD` is the latest commit of the branch's open PR. Then it comments the report on the PR and sets a **`game-tests` commit status** on that SHA (success or failure, "5 of 5 passed (local run)"). The status shows in the PR's checks; a new push leaves the new commit without one, so a stale pass can't pass for current.
- **It's an attestation, not proof:** the report is a file the developer could edit. It stops mistakes (wrong commit, unpushed or uncommitted changes), not cheating; CI is the answer to that.

**The test plan:** what the tests cover, in Given/When/Then, is in `tests/game/features/`, one file per feature, each scenario tagged with its test; `make test` checks the two match (see [PROJECT.md, Workflow](../PROJECT.md#workflow)).

**Writing a test:** a root cue that fires on `event_cue_signalled`, sets up its scenario, and signals `Report` once with `table[$name, $ok, $detail]` from either a result cue or a timeout cue. Then add it to `$Tests`. Use the helpers for spawning and forcing bails, and set any mod setting the test relies on, so settings overridden at deploy time can't change its outcome. Clean up spawned ships so tests don't affect each other. Don't put a `delay` on a cue whose sub-cues need its actions to have run first (see below).

## First runs in game

Four runs on 2026-10-20, X4 9.00, with only A Pirate's Life enabled in the profile.

| Run | Result | What we learned |
| --- | --- | --- |
| 1 | X4 exited at once, no log | **Starting `X4.exe` directly doesn't work:** it hands over to Steam and the arguments are lost. The runner now launches through Steam |
| 2 | X4 never started (120 s) | **Steam asked first:** the first launch from outside Steam opened a Steam dialog that had to be accepted. **Only once:** after Erik accepted it, later launches started straight away with no prompt (its wording wasn't recorded). What makes Steam ask again is unknown, so the runner's launch-timeout error says to look for the prompt |
| 3 | Pipeline worked; 0 tests ran | Autostart, gamestart, harness, log reading and closing the game all worked. Two harness bugs and one runner bug (below) |
| 4 | **3 of 3 passed** in 2 min 21 s | `pilot_bail_intact`: vanilla would have sabotaged the ship (pilot skill 53); hull 100%, 4 items kept. `claim_intact`: the marine claimed it about 16 s (game time) into the test, with vanilla max damage 80 prevented |

**Answered:**

- **The autostart works:** the extension's Lua loads, the main menu reports `startmenu`, and `NewGame` starts the test gamestart about 8 s after the menu appears. No start-up dialog got in the way. In the new game the module name is still empty when the Lua runs, so the `startmenu` check is what stops it looping.
- **Sub-cues start when the parent's conditions are met, not after its `delay`.** `Begin` (a sub-cue of `Run`) fired at 0 s, before `Run`'s actions had set `$Tests`. Fix: no delay on `Run`; the 5 s settle delay moved into `Begin`.
- **`set_timewarp_factor` takes a time:** `factor="6s"`, not `6`.
- **Script errors are followed by `* Expression:` and `* Action:` lines** that can quote our markers, so a failing `debug_text` once looked like `DONE`. The runner now skips those lines and only accepts `DONE` after `RUN START`.
- **God off makes vanilla noisy:** about 380 `Error in MD cue` lines per run from DLC and story setup cues that look for stations god never built (`Setup_DLC_Pirate`, `Story_Criminal`, `Setup_DLC_Terran` …). They don't affect our tests, and the runner ignores them because they don't mention the mod.
- **The claim scenario works:** `<person role="marine">` gives the frigate marines, and with a `Wait` order and `foundabandonedship` = `claim` it sends one within seconds.
- **The log is complete** at `quit_to_desktop`, and X4 quits by itself.
- **Learned from the capture-operation tests** (2026-10-20):
  - **Script variables can't be stored on a ship.** `set_value name="$ship.$x"` logs `Failed to set component…`; only NPCs (entities) have that storage. Use a global table keyed by the object instead.
  - **`shoot_at` is only allowed in an AI script's `visible` attention block.** The script fails to load otherwise.
  - **Order params without a `text` must be `type="internal"`**, or the script logs an error at load.
  - **Combat tests need a fixed loadout.** With `loadout level` the wingman rolled different weapons each run: slow mass drivers barely landed a shot, and torpedoes one-shot the target. The test extension defines its own loadout (`libraries/loadouts.xml` diff) and spawns it with `<loadout ref="…"/>`; MD's `create_ship` can't list macros itself.
  - **Player-owned ships won't fire on a neutral** until it's hostile to the player (vanilla's "Mark as hostile" relation boost).
  - **`event_object_attacked` only fires now and then**; `event_object_hull_damaged` / `event_object_shield_damaged` fire on each damage.
  - **Moving a ship with `warp`:** in the same actions as its `create_ship`, the warp doesn't stick (the ship stays near its spawn point); warp it a couple of seconds later, with explicit coordinates in the player's zone (`<position x="player.occupiedship.position.x" … z="… + 20km"/>`). The new position also isn't readable in the same actions, so measure distances later.
  - **Sub-cue delays count from the parent's activation** (see first runs, above): a "1 s after the warp" sub-cue under a 2 s cue ran before the warp. Give the later step the longer delay.
  - **Hold-fire test target starts worn down** (0 shields, 80% hull): with full shields, vanilla's dogfighting AI sometimes parked 1.3 km out and only chipped at them for minutes.
  - **…and its shields are held at 0 until the hull is under 75%.** Shields recharge 15 s after the last hit, at about 125 hp/s on this fighter, more than two pulse lasers (209 dps) land in a dogfight. The wingman lands most of its hits on the way in, so if the last one before the gate came late, the hull stalled just above it: once in five runs on 2026-10-21, at 75.4% for the full 180 s, with the wingman still firing as it should. Below the gate the shields recharge as usual, so the suppress phase still gets tested.
  - **SETA drops** whenever something interrupts it (help messages, comm calls); the harness switches it back on (`KeepSeta`).
  - **Weapon groups are numbered from 0:** a spawned ship's guns are in active primary group 0, and `reset_weapongroups` plus activating group 1 left it with nothing to fire.
- **Timing:** about 2½ minutes from `make game-test` to the report, most of it X4 starting and loading the universe; the tests themselves take about 25 s of game time.

## Fit with `make test` and CI

- **`make test` stays fast and headless.** It runs the runner's Pester tests, not the game.
- **`make game-test` runs the game** (Windows, through WSL interop or `.\tools\run-game-tests.ps1`). Run it before opening a PR that changes mod behavior, and add a test with each feature (its spec's "Done when").
- **CI:** hosted runners can't run X4. A self-hosted runner on Erik's PC could, but only on `workflow_dispatch` or pushes to `main`, never on PRs from forks: a self-hosted runner executes the PR's code on that machine. Not worth it until there are enough tests to forget to run.

## Ideas to research later

Not agreed work; kept so these paths aren't forgotten. The current setup (launch through Steam, local runs) stays for now.

### Egosoft's NoSteam executable

Egosoft offers an official NoSteam build to owners (X4 registered in their forum profile, or a linked Steam account): `X4_nonsteam.exe`, copied into the game folder ([FAQ](https://www.egosoft.com/support/faq/faq_answer_en.php?answer=2413), [downloads](https://www.egosoft.com/download/x4/bonus_en.php), which list a 9.00 package for Windows and Linux). Erik's 7.60 SWI copy already runs it through a desktop shortcut with our arguments.

**PoC done (2026-10-28): it works, and runs the whole suite (48 of 48 passed), but it isn't faster and doesn't allow a second game at once.** Details in [profile folders and parallel runs](#profile-folders-and-parallel-runs).

- **Why:** the runner could pass its own arguments (no Steam launch options to set up, no Steam prompt), and no Steam means no one-session limit and no Workshop sync loading other mods.
- **The package** is just the exe (`X4_9.00_nonsteam_Windows.zip`, 18 MB, holding a 55 MB `X4_nonsteam.exe` dated 2026-06-10). It goes into a copy of the 9.00 install, next to `X4.exe`. The log reports code revision 611726, the same as the Steam build.
- **Profile folder:** without `-personalfolderid`, NoSteam uses the root `Documents\Egosoft\X4\` (on Erik's machine, the 7.60 SWI profile). With `-personalfolderid <number>` it uses `Documents\Egosoft\X4\<number>\`; see below.
- **Versions:** patches only come through Steam, so each X4 update needs the matching NoSteam download, and the copy needs refreshing from the Steam install. The runner should check the executable's version against the game data (the log's `Entering startmenu in 9.00 (611726)` line).
- **Licensing:** whether running it on several CI machines at once fits Egosoft's terms.
- **Speed:** no faster than Steam. To the start menu: 39 to 42 s with a new profile, 34 s once its shader cache was built, against 31 to 43 s through Steam. Launch to `DONE`: 2 min 6 s and 2 min 30 s, against about 1 min 45 s for a Steam run the same day. One run each, with focus not controlled, so it's within run-to-run noise.

### Profile folders and parallel runs

Spike 2026-10-28: can each 9.00 install get its own profile folder (`config.xml`, `content.xml`, saves, `debuglog.txt`), so several installs run game tests side by side for parallel Claude sessions? **Separate profiles: yes. Side by side: no, one X4 per Windows login session.**

**Setup.** Two full copies of the Steam install, `E:\SteamLibrary\steamapps\common\X4 Foundations - 9.00-a` and `- 9.00-b` (32 GB each with DLCs, under 2 minutes each with `robocopy /MT:8` on the same drive), each with `X4_nonsteam.exe` in it. The copies leave out the Steam install's `extensions\`: X4 keeps the **DLCs** there (`ego_dlc_*`, 8.6 GB), so those were copied back in, plus kuertee's UI Extensions (a Vortex-managed folder of symlinks, copied as real files). Our mod went in with `X4_PATH=<copy> ./deploy.sh --working-tree` and the test extension by hand. The Workshop mods synced into the Steam install don't load in a copy, which answers [open question 5](#open-questions) for these runs. Launched with `-personalfolderid <id> -skipintro -debug all -logfile debuglog.txt -scriptlogfiles`.

| Try | Result |
| --- | --- |
| `-personalfolderid 90000001`, folder created beforehand | Works: everything went into `Egosoft\X4\90000001\` (`debuglog.txt`, `uidata.xml`, `userdata*.xml`, `pipelinecache.bin`); the root and Steam profiles weren't touched. No saves in the load menu, as expected |
| `-personalfolderid 90000002`, no folder | Works: X4 creates the folder itself |
| A full test run in copy A on `90000001` | **48 of 48 passed**, autostart and quit as through Steam |
| Copies A and B at once (`90000001`, `90000002`) | **B refused:** a "Game is already running!" dialog, no log. A ran on and passed 48 of 48 |

- **What `-personalfolderid` expects is a number.** A full path or a plain folder name (tried 2026-10-17/18, and by the 7.60 shortcut) falls back to the root folder; a numeric ID gets `Documents\Egosoft\X4\<id>\`, like the Steam account folder. Not tried with Steam's `X4.exe`, which drops its arguments when started directly anyway ([first runs](#first-runs-in-game)).
- **The single-instance lock** is a named mutex, `EGOSOFT_X4_INSTANCE` (`CreateMutexW` in `X4_nonsteam.exe`). With no `Global\` prefix it lives in the login session's namespace, so separate installs, profiles or executables don't help. Steam's `X4.exe` has the same message, but the mutex name isn't readable in it (likely packed), so whether a Steam game and a NoSteam game also block each other is untested; most likely yes.
- **Ways around it, not tried:** Sandboxie-Plus (gives each sandbox its own named objects; an install), closing the mutex in the running game with Sysinternals `handle.exe -c` (brittle), another login session (Windows 10/11 Pro allow one interactive session at a time; `runas` shares the current one), or separate machines/VMs (a VM needs a GPU for X4). Not pursued: game tests are the only thing that needs the game, a shared queue serves every session, and two games at once would compete for the GPU and CPU, which is what already breaks the [timing tests](#first-runs-in-game) when X4 runs slower in the background.
- **Resources, not measured:** the PC (32 GB RAM, RTX 3060, Ryzen 5 5600X) never ran two games. One game used about 3 GB of RAM while starting the test game.
- **`-nocputhrottle -nosoundthrottle`** were on for the side-by-side run. B's dialog probably took focus, and A still passed `capture_wing_holds_fire` and `booty_order_hands_over`, the two tests that fail unfocused. Not confirmed (nobody checked which window had focus), but worth trying for the plan item on [unfocused runs](../IMPLEMENTATION_PLAN.md#phase-0-dev-setup-and-tooling).
- **The runner as it is can't drive a copy:** `-GameExe` starts the exe without arguments, and `Resolve-LogPath` takes the numbered profile folder with the newest `debuglog.txt`, so a test profile like `90000001` could pull a Steam run onto the wrong log. Using a copy needs `-LogPath` passed and the game's arguments added.

Left on Erik's machine after the spike: copies A and B (64 GB on E:), profile folders `90000001` and `90000002` (no saves), the NoSteam exe in `E:\x4-dev\nosteam-9.00\`, and a backup of the root profile's top-level files in `E:\x4-dev\backups\x4-root-profile-2026-10-28\` (not needed: the root profile wasn't written).

### A shared game-test queue

Proposal, not agreed (Erik, 2026-10-28: only `make game-test` needs the game, so sessions can share one queue instead of running games in parallel). How it could work:

- **A machine-wide lock around deploy and run.** `make game-test` deploys into the install and then runs, so both happen inside the lock. The runner opens a lock file exclusively (`FileShare.None`, e.g. `%LOCALAPPDATA%\apirateslife\game-test.lock`) and holds it open for the whole run, so a crashed or killed runner frees it by itself. It writes who holds it (branch, commit, start time, PID) for waiting sessions to print.
- **Waiting:** a session that can't get the lock prints the holder and retries every few seconds, up to a timeout (a whole run is about 2 minutes, so tens of minutes covers a queue of several). First come, first served is enough at our size; a ticket file could make it strict.
- **Erik's own game counts too:** if any X4 process is running (playing, or a test run started by hand), the runner waits like for the lock, rather than deploying into a running game or hitting "Game is already running!".
- **Optional, with the NoSteam item:** run the queue against a test-only NoSteam copy with its own profile folder, so test runs never touch Erik's Steam install, profile or Workshop mods. The lock is still needed (one game per session).
- **More throughput later** means more machines (or GPU VMs) with one queue each, as in [CI/CD](#cicd).

### Comparing a PR's run with `main`

Show on the PR what changed against the latest run on `main`: tests that newly fail or pass, and new tests. Possible routes: keep each posted report (e.g. a `game-tests` status on `main` commits plus the report in a gist or a `game-test-reports` branch), then diff the PR's report against the one for its merge base. Not needed for the MVP.

### CI/CD

For when contributors join: their game-test results should show on their PRs without anyone pulling their branch.

- **Machines:** hosted runners can't run X4 (no GPU, Steam or licence). Options: a self-hosted runner on Erik's PC, or a cloud GPU VM (e.g. EC2 `g4dn`) started per job from a prebuilt image. Packer rather than Vagrant for the image: local hypervisors mostly can't give X4 a Vulkan GPU, and Vagrant's cloud providers are largely unmaintained.
- **Steam account:** a dedicated account that owns X4 and all DLCs, used only for testing. One session at a time, so runs are queued: one runner label, since GitHub's `concurrency` keeps only one pending job and cancels the rest. More parallel machines need more accounts (or NoSteam, licence permitting).
- **Security:** a self-hosted runner executes the PR's code, so runs for outside contributors wait for Erik's approval (an environment with required reviewers), with throwaway VMs and the Steam login scoped to that environment.
- **Mainline:** game tests on `main` after every merge to catch conflicts that pass separately, gating releases. GitHub's merge queue would test PRs together before they land; as far as we know it needs an organization-owned repo.
- **Release:** an automated release from a green `main` (`make release`, the Workshop through Egosoft's WorkshopTool, Nexus if it can be automated). Target: a merged PR reaches players within an hour or two.
- **Reuse:** the image, runner and MD harness could become a standalone X4 game test kit for other modders.


## UI tests, when we need them

The in-game settings page (planned through kuertee's UI Extensions) is the first UI we'd want to test. In order of preference:

1. **Drive it through Lua.** The test extension's Lua can call the same menu functions a click would, and report state back to MD with `AddUITriggeredEvent`. No pixels involved.
2. **A thin input layer** only for what Lua can't reach: a Windows helper that focuses X4, sends keys and clicks (`SendInput`), and takes screenshots. Python (`pyautogui` plus OpenCV template matching, OCR only if it must read text) is the quickest to write; keep it under `tools/` and call it from the runner.
3. Screenshots as **artifacts on failure** are useful even without matching.

## Open questions

1. **A faster start still:** about 35–45 s of each run is X4 starting up to its main menu, which we don't control; the undocumented module option above might skip the menu.
2. **Other `X4.exe` options** (strings next to the known ones, unverified): `-nocputhrottle` and `-nosoundthrottle` (keep running at full speed in the background, so the PC stays usable during a run), `-disablesound`, `-usedefaultconfig` / `-dontsaveconfig` (a clean, unchanged config), `-noworkshopsync`, `-enablexmlvalidation` (could catch bad XML in our files at load). Through Steam they'd go in the Steam launch options.
3. **The out-of-sight claim path** (`attention min="unknown"`) needs the player far away. Tests could move the player with `warp`.
4. **Other enabled mods** would load into test runs too. The runner could list the enabled extensions in its report, so a run is reproducible.

## Next steps

1. Add a test with each new feature.
2. Maybe: a test that a missing setting counts as on (the patches' `not (global.$X? and global.$X == 0)`).
