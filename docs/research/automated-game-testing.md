# Automated in-game testing

**Status: WIP (2026-10-19).** Researched against the 9.00 game files and `X4.exe`; a proof of concept is built but **hasn't run in the game yet**. The open questions below are what the first run has to answer.

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
| `…/md/apirateslife_tests.xml` | The harness and three tests, run one after another |
| `…/md/notifications.xml` | Test-only patch that switches on `$testcheat` |
| `tools/run-game-tests.ps1` | The runner |
| `tests/GameTests.Tests.ps1` | Pester tests for the runner (log parsing, report, whole runs against a fake game), run by `make test` and CI |
| `Makefile` | `make game-test`: deploys the working tree, then runs the runner through Windows PowerShell |

**Tests:**

| Test | Covers |
| --- | --- |
| `eject_chance_doubled` | `AdjustEjectChance`: 0→0, 10→20, 30→60, 50→100, 70→100 |
| `pilot_bail_intact` | A forced pilot bail: our `Bailed` signal fires with `$pilot`, the ship is ownerless, hull and equipment unchanged ([bail hook](../specs/bail-hook.md), [capture without damage](../specs/claim-no-damage.md)) |
| `claim_intact` | A marine claims an ownerless fighter: it becomes the player's with hull and equipment unchanged. The "visible" attention level only |

**Log protocol** (every line starts with `[apirateslife-test]`): `RUN START <n> tests`, `PASS <name>: <detail>` / `FAIL <name>: <detail>`, `DONE passed=<n> failed=<n>`. A run fails if any test fails, fewer than `<n>` results arrive, `DONE` never comes (game exited or timed out), or the log has errors mentioning the mod (signature warnings excluded).

**Validation so far:** every XML file validates against the 9.00 XSDs (`md.xsd`, and `gamestarts.xsd` with the diff applied); vanilla `notifications.xml` validates against `md.xsd` with both our patches applied; the `$testcheat` selector matches exactly one element. The runner's Pester tests pass in Windows PowerShell 5.1.

### A run

```
make game-test        # or: .\deploy.ps1 -WorkingTree; .\tools\run-game-tests.ps1
```

1. The runner checks the mod is deployed and X4 isn't running, copies the test extension into `extensions\apirateslife_tests`, and deletes the old `debuglog.txt`.
2. It starts `X4.exe` with `-skipintro -debug all -logfile debuglog.txt -scriptlogfiles`.
3. The Lua autostart starts the test gamestart; MD runs the tests and quits the game.
4. The runner prints each result as it arrives, closes the game if it's still running after `DONE` (30 s grace) or at the timeout (900 s), removes the test extension, writes `tests/game/results.xml` (JUnit) and exits 0 or 1.

**Writing a test:** a root cue that fires on `event_cue_signalled`, sets up its scenario, and signals `Report` once with `table[$name, $ok, $detail]` from either a result cue or a timeout cue. Then add it to `$Tests`. Clean up spawned ships so tests don't affect each other.

## Fit with `make test` and CI

- **`make test` stays fast and headless.** It runs the runner's Pester tests, not the game.
- **`make game-test` runs the game** (Windows, through WSL interop or `.\tools\run-game-tests.ps1`). Run it before opening a PR that changes mod behavior, and add a test with each feature (its spec's "Done when").
- **CI:** hosted runners can't run X4. A self-hosted runner on Erik's PC could, but only on `workflow_dispatch` or pushes to `main`, never on PRs from forks: a self-hosted runner executes the PR's code on that machine. Not worth it until there are enough tests to forget to run.

## UI tests, when we need them

The in-game settings page (planned through kuertee's UI Extensions) is the first UI we'd want to test. In order of preference:

1. **Drive it through Lua.** The test extension's Lua can call the same menu functions a click would, and report state back to MD with `AddUITriggeredEvent`. No pixels involved.
2. **A thin input layer** only for what Lua can't reach: a Windows helper that focuses X4, sends keys and clicks (`SendInput`), and takes screenshots. Python (`pyautogui` plus OpenCV template matching, OCR only if it must read text) is the quickest to write; keep it under `tools/` and call it from the runner.
3. Screenshots as **artifacts on failure** are useful even without matching.

## Open questions (for the first in-game run)

1. **Does the autostart work?** Does the extension's Lua load with Protected UI Mode on (SirNukes' notes say only its external pipes are blocked), does `GetGameStartName()` return `startmenu` in the main menu, and does `NewGame` work while start-up dialogs are open (news, "modified game")?
2. **Launching:** does running `X4.exe` directly (Steam running) keep our arguments, or does Steam restart it with the Steam launch options? Those already include ours, so either should work. If not, launch through `steam.exe -applaunch 392160 …`.
3. **Does the quiet gamestart work?** Errors from vanilla scripts with god off, load time, and whether SETA engages there.
4. **The claim test:** does the frigate get marines from `<person role="marine">`, notice the fighter and claim it within 180 s?
5. **Run time:** game start plus loading, likely 1–3 minutes. Is a faster start possible (`thevoid`'s empty galaxy, or the undocumented module option above)?
6. **Is the log complete** when `quit_to_desktop` runs (the harness waits 2 s first)?
7. **Other `X4.exe` options** (strings next to the known ones, unverified): `-nocputhrottle` and `-nosoundthrottle` (keep running at full speed in the background, so the PC stays usable during a run), `-disablesound`, `-usedefaultconfig` / `-dontsaveconfig` (a clean, unchanged config), `-noworkshopsync`, `-enablexmlvalidation` (could catch bad XML in our files at load).
8. **The out-of-sight claim path** (`attention min="unknown"`) needs the player far away. Tests could move the player with `warp`.

## Next steps

1. First in-game run: answer the questions above, fix what breaks, update this note.
2. Add a test with each new feature; add `settings` tests once capture settings merge (flags off → vanilla damage).
3. Tidy the harness once it has a few more tests: shared helpers for spawning ships and checking hull and equipment.
