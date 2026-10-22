# Spec: In-game settings page

Plan item: Phase 1, "In-game settings page through kuertee's UI Extensions" · Status: Draft

## Goal

With kuertee's UI Extensions installed, the player changes the mod's settings in game: Settings → A Pirate's Life, with an on/off button for each setting a player would want to change. A choice applies at once and stays with that save. The player can also save the current values as **my defaults**, kept in their X4 profile: every new game starts from them, and any save can load them. Without UI Extensions the mod works as today, from the config file alone.

## Context

- Settings today: [capture settings](capture-settings.md) and [capture operation](capture-operation.md#design). `md/apirateslife_config.xml` (library `Defaults`) sets `global.$APiratesLife_<Name>`; `md/apirateslife_settings.xml` (`OnLoad`) re-applies it on every start and load, so it would overwrite anything set in game. Patches read the globals and treat a missing value as on.
- How the options hook works on 9.00, the option entry shapes, and Protected UI Mode: [third-party UI APIs](../research/third-party-ui-apis.md#the-options-hook-on-900-2026-10-21).
- Vanilla Lua ↔ MD bridge: [same note](../research/third-party-ui-apis.md#the-lua--md-bridge-vanilla).
- Profile-wide storage: an add-on's `ui.xml` can declare `<savedvariable name="…" storage="userdata"/>`, a Lua table X4 keeps in the player's profile across all saves (`ui/core/addon.xsd`; vanilla keeps its map filters this way, UI Extensions its mod sort order). It belongs to the X4 profile, so each Steam profile has its own.
- Asked for by Erik (chat, 2026-10-21): set it once and keep it, like global settings, but still tune each save, like Bannerlord mods that save per-game settings and keep them as a reusable profile.

## Design

- **Only player choices go on the page** (Erik, chat, 2026-10-21): the settings were first made configurable for testing, and the page shouldn't carry that noise.
  - On the page: `IntactOnEject`, `IntactOnClaim` (taste: intact prizes or vanilla's damage) and `CaptureWingFullChance` (difficulty: wingmen as good at forcing bails as you, or vanilla's quarter).
  - Config file only, under a "Tuning" heading: `CaptureHoldHull` and `CaptureFloorHull`. 75% is vanilla's bail gate, and other values only change how hard wingmen hit before switching to shields; players care that prizes survive, not about the percentages. They follow the file alone (and `deploy --set` in tests), never the save or my defaults.
  - Rejected: an "Advanced" section with the percentages. It brings back the noise, plus slider ranges, clamping and warnings for values that can stop bails altogether.
- **Three layers, each filling what the one above leaves empty:** the save's own values, then my defaults, then the config file. Patches keep reading the same `global.$APiratesLife_<Name>` values, so nothing else changes.
- **Per-save values** live in a table `global.$APiratesLife_Chosen` (saved with the game), by name. On every start and load `OnLoad` applies the config, then the save's values over it, so the config file's own reapplication never undoes a choice.
- **My defaults** live in Lua, in a `userdata` saved variable (`__userdata_apirateslife`). The page has "Save as my defaults" (copies this save's current values) and "Load my defaults" (copies them into this save). One set for now; several named profiles are an idea for later.
- **New games start from my defaults.** A save that has never had settings (a new game, or an old save meeting this version) is seeded once: when the Lua reports in after the start or load, it sends my defaults and MD copies them into the save's table. After that, changing my defaults doesn't touch that save until "Load my defaults" is used there. A flag (`global.$APiratesLife_Seeded`) marks the save as seeded. Until the Lua reports in (a moment after the start), the config values apply.
- **Reset:** "Reset to config file values" clears the save's table and re-applies the config. My defaults stay as they are.
- **Settings the mod adds later** are missing from older saves and older defaults, so they come from the config file. Nothing needs migrating.
- **MD owns the save's values.** Lua sends a change with `AddUITriggeredEvent("APiratesLife_Settings", <Name>, <value>)` (`"Reset"`, `"LoadDefaults"` with the defaults table, `"LuaLoaded"`); MD checks it, sets the global and the table, logs it, and mirrors the current values to the player blackboard (`player.entity.$APiratesLife_Settings`) for Lua to read with `GetNPCBlackboard`. Lua also updates its own copy at once so the page doesn't wait a frame. Unknown names are logged and ignored.
- **Values:** the page's settings take 0 or 1; MD ignores anything else and logs it. The config file stays unchecked, as today.
- **The page** (`ui/apirateslife_options.lua`, loaded by our `ui.xml` after `ego_gameoptions`): a `displayOptions_modifyOptions` callback adds an "A Pirate's Life" entry at the end of the in-game Settings page (hidden in the start menu, which has no save) and defines our page in `config.optionDefinitions`. It returns new tables, never editing the menu's own (the callback runs on every redraw). The page lists the three switches and the three actions (save as my defaults, load my defaults, reset). Each switch has a mouse-over text taken from the config file's comments. English text in the Lua for now; a text file when we localize.
- **Optional dependency:** `content.xml` declares UI Extensions (`kuerteeUIExtensionsAndHUD`) with `optional="true"`, so the game loads it first when present. Without it the options menu has no `registerCallback`; our Lua logs that and adds no page, but still reports in and seeds new games from my defaults (none can be saved without the page, so in practice the config applies). SWI's bundled menus provide the same callback, so SWI players get the page too.
- **Lua reports in:** after each start and load, the Lua sends `"LuaLoaded"` with whether UI Extensions was found; MD logs "settings page available" or "config file only". It makes support questions and the game tests answerable from the log.
- **Config file header** says in-game settings exist (with UI Extensions), that the save's values and my defaults come first, and that the page's reset brings the file's values back.

## Tasks

- [ ] `md/apirateslife_settings.xml`: the save's table, apply order on load, seeding, UI event handler with ranges, blackboard mirror, reset, logging
- [ ] `ui.xml` and `ui/apirateslife_options.lua`: the page through `displayOptions_modifyOptions`, my defaults in `userdata`, UI Extensions check, load report
- [ ] `content.xml`: optional dependency on UI Extensions
- [ ] `md/apirateslife_config.xml` header
- [ ] Game tests (the bridge and MD side; the test extension's Lua sends the same UI events as the page)
- [ ] Manual test of the page with UI Extensions installed
- [ ] Docs: PROJECT.md current status, plan, specs README

## Done when

Scenarios: [`tests/game/features/in-game-settings.feature`](../../tests/game/features/in-game-settings.feature).

- A setting changed through the UI event applies at once and survives a load with the config file's value different.
- Settings the save hasn't set still follow the config file.
- A save with no settings is seeded once from my defaults; a seeded save ignores later default changes until it loads them.
- Reset brings back the config file's values; invalid values, unknown names and the tuning settings (not on the page) are ignored.
- Our Lua loads and reports in without UI Extensions, and the game then runs on the config file as before.
- By hand, with UI Extensions installed: the page shows in game (not in the start menu), each button changes its value and the log shows it, the values are still there after saving and loading, and my defaults saved in one game start the next new game and survive restarting X4.

## Open questions

- When X4 writes `userdata` saved variables to disk (at once, on a save, or only on a clean exit). If only on exit, a crash loses newly saved defaults; check by hand.
- Several named profiles (Bannerlord style): needs a name entry and a list on the page. Later, if one set of defaults isn't enough.
- Drawing the menu itself isn't automated: the game-test runner doesn't install UI Extensions. Installing it for one test run is possible later.
