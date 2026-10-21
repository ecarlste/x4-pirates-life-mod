# Spec: In-game settings page

Plan item: Phase 1, "In-game settings page through kuertee's UI Extensions" · Status: Draft

## Goal

With kuertee's UI Extensions installed, the player changes the mod's settings in game: Settings → A Pirate's Life, with an on/off button for each switch and a slider for each percentage. A choice applies at once and stays with that save, whatever the config file says. Without UI Extensions the mod works as today, from the config file alone.

## Context

- Settings today: [capture settings](capture-settings.md) and [capture operation](capture-operation.md#design). `md/apirateslife_config.xml` (library `Defaults`) sets `global.$APiratesLife_<Name>`; `md/apirateslife_settings.xml` (`OnLoad`) re-applies it on every start and load, so it would overwrite anything set in game. Patches read the globals and treat a missing value as on.
- How the options hook works on 9.00, the option entry shapes, and Protected UI Mode: [third-party UI APIs](../research/third-party-ui-apis.md#the-options-hook-on-900-2026-10-21).
- Vanilla Lua ↔ MD bridge: [same note](../research/third-party-ui-apis.md#the-lua--md-bridge-vanilla).

## Design

- **Per save.** A choice is stored in the save and applies to that game only; a new game starts from the config file. Gameplay settings belong to a playthrough, like the difficulty, and MD has no storage shared between saves (Lua's profile-wide `userdata` exists, but would reach MD only after the load, when patches may already have run). Rejected: global settings.
- **The config fills only what the player hasn't chosen.** A table `global.$APiratesLife_Chosen` (saved with the game) holds the settings changed in game, by name. On every start and load `OnLoad` applies the config, then the chosen values over it. The patches keep reading the same `global.$APiratesLife_<Name>` values, so nothing else changes. A setting never touched in game keeps following the config file.
- **Reset:** a "Reset to config file values" entry on the page clears the table and re-applies the config.
- **MD owns the values.** Lua sends a change with `AddUITriggeredEvent("APiratesLife_Settings", <Name>, <value>)` (`"Reset"` for reset); MD checks it, sets the global and the table, logs it, and mirrors the current values to the player blackboard (`player.entity.$APiratesLife_Settings`, a table by name) for Lua to read with `GetNPCBlackboard`. Lua also updates its own copy at once so the page doesn't wait a frame. Unknown names are logged and ignored.
- **Ranges:** switches take 0 or 1. Sliders in steps of 5: hold line 50–75%, floor 10–45%, so the floor stays under the hold line. MD clamps page values to the same ranges; the config file stays unchecked, as today.
- **The page** (`ui/apirateslife_options.lua`, loaded by our `ui.xml` after `ego_gameoptions`): a `displayOptions_modifyOptions` callback adds an "A Pirate's Life" entry at the end of the in-game Settings page (hidden in the start menu, which has no save) and defines our page in `config.optionDefinitions`. It returns new tables, never editing the menu's own (the callback runs on every redraw). Each entry has a mouse-over text taken from the config file's comments. English text in the Lua for now; a text file when we localize.
- **Optional dependency:** `content.xml` declares UI Extensions (`kuerteeUIExtensionsAndHUD`) with `optional="true"`, so the game loads it first when present. Without it the options menu has no `registerCallback`; our Lua logs that once and does nothing else. SWI's bundled menus provide the same callback, so SWI players get the page too.
- **Lua reports in:** on load, the Lua sends `"LuaLoaded"` with 1 or 0 for whether UI Extensions was found; MD logs "settings page available" or "config file only". It makes support questions and the game tests answerable from the log.
- **Config file header** says in-game settings exist (with UI Extensions), override the file for that save, and that the page's reset brings the file's values back.

## Tasks

- [ ] `md/apirateslife_settings.xml`: chosen-values table, apply order on load, UI event handler with ranges, blackboard mirror, reset, logging
- [ ] `ui.xml` and `ui/apirateslife_options.lua`: the page through `displayOptions_modifyOptions`, UI Extensions check, load report
- [ ] `content.xml`: optional dependency on UI Extensions
- [ ] `md/apirateslife_config.xml` header
- [ ] Game tests (the bridge and MD side; the test extension's Lua sends the same UI events as the page)
- [ ] Manual test of the page with UI Extensions installed
- [ ] Docs: PROJECT.md current status, plan, specs README

## Done when

Scenarios: [`tests/game/features/in-game-settings.feature`](../../tests/game/features/in-game-settings.feature).

- A setting changed through the UI event applies at once and survives a load with the config file's value different.
- Settings not changed in game still follow the config file.
- Reset brings back the config file's values; out-of-range values are clamped; unknown names are ignored.
- Our Lua loads and reports in without UI Extensions, and the game then runs on the config file as before.
- By hand, with UI Extensions installed: the page shows in game (not in the start menu), each control changes its value and the log shows it, and the values are still there after saving and loading.

## Open questions

- The slider ranges (hold 50–75, floor 10–45): enough room, or should the page allow anything the config file does?
- Drawing the menu itself isn't automated: the game-test runner doesn't install UI Extensions. Installing it for one test run is possible later.
