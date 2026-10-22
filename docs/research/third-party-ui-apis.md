# Third-party UI APIs on X4 9.0

**Status: done (2026-10-19; 9.00 options hook added 2026-10-21).** How mods add in-game UI on 9.0, which shared APIs are healthy, and how SWI does it. Led to the "Key decisions" UI rule in [PROJECT.md](../PROJECT.md#key-decisions).

## Summary

- **kuertee's UI Extensions** is the base to build on: actively maintained, and what SWI uses for all its UI pages.
- **SirNukes' Mod Support APIs** only where there's no alternative: not updated since Dec 2025, with 9.0 reports of failures.
- **The Lua ↔ MD bridge is vanilla.** UI Extensions is only needed for the hooks into vanilla menus.
- **Vanilla has no way for mods to add their own options**; its "extension settings" only enable/disable and sync each extension.

## SirNukes' Mod Support APIs

- [bvbohnen/x4-projects](https://github.com/bvbohnen/x4-projects) (MIT). Last push 2025-12-08 (v1.95). v1.91 updated for X4 8.0 and added Protected UI Mode support (only the external pipes API is disabled in that mode).
- 9.0 reports (Workshop comments via search results, Aug–Oct 2026): shows red in the Extensions menu on a fresh 9.0 install with dependent mods failing; "No menus registered" in Extension Options; a 1.96.5 build reported to fail randomly, with 1.95 "kicking you out of the menus" instead. Other players report no problems.
- Community fixes: [GitHub issue #34](https://github.com/bvbohnen/x4-projects/issues/34) (Sept 2026; a "temporary fix" that clears stale `player.entity.$simple_menu_args` / `$interact_menu_args` on menu reset plus Lua changes, pinned to 1.95) and [Nexus 2373](https://www.nexusmods.com/x4foundations/mods/2373) "(FIXED 9.0) … Bug Fix Compatibility Patch", whose author attributes "No menus registered" to the API processing one registration per signal.
- A "Community Edition" fork (Valador) is reported to conflict with the original.
- Its Simple Menu Options API is easy to use from MD alone (register an option with a callback cue; values stored in the save). We built our capture settings on it, then dropped it for the reasons above (see [capture-settings spec](../specs/capture-settings.md)).

## kuertee's UI Extensions

- [kuertee/x4-mod-ui-extensions](https://github.com/kuertee/x4-mod-ui-extensions), v9.0.0.18 (2026-10-16), last push 2026-10-18. No license file.
- **No dependencies** in its `content.xml`. Some features integrate with SirNukes optionally: custom action groups in the right-click menu still add their actions through SirNukes' `Interact_Menu_API.Add_Action`.
- Replaces vanilla menu files (`.xpl`) to add **callbacks**: `menu.registerCallback(name, function, id)` (e.g. `ui/addons/ego_gameoptions/gameoptions.xpl:14583`). Hook points include `displayOptions_modifyOptions` in the options menu (`:9607`), and many in the map, Player Info and other menus.
- Also offers custom Property Owned tabs and a `uix_deactivate_mod` UI event when the player deactivates a mod (useful for cleanup).
- **Protected UI Mode can stay on:** kuertee plays with it on and recommends ignoring the game's prompt to disable it. Only switching it while the mod is active stops menus reloading.
- No settings registry of its own; kuertee mods offer settings through SirNukes' menu when it's installed.

## How SWI builds its UI

Studied SWI 0.86 (X4 7.60, from the local 7.60 install) and 0.90 (X4 8.00, 2025-12-06). Snapshots in `E:\x4-dev\reference\mods\swi-0.86\` and `…\swi-0.90\`: the loose UI, plus MD scripts, AI scripts, libraries and text pulled from the catalogs with XRCatTool `-include`, and SWI's replacement menus (`subst02\`). The 18 GB asset data was deleted after extraction. Reference only, per the SWI etiquette in [DESIGN.md](DESIGN.md#design-pillars-and-compatibility-architecture).

- **Loading:** a `ui.xml` add-on (identical in both versions) lists loose Lua files under `ui/` and the vanilla menus they extend (`ego_gameoptions`, `ego_detailmonitor`, `ego_interactmenu`, `ego_detailmonitorhelper`).
- **Hooks:** UI Extensions' `registerCallback` everywhere: 28 uses across 9 of 10 files in 0.86, 40 in 0.90 (new ones include `createPlayerInfo_on_start`, `createInfoFrame_on_info_frame_mode`, `createFactionDetailsContext_on_before_detailtable`, `onRowChanged`, `onClearUIData`). `sw_gameoptions.lua` uses `displayOptions_modifyOptions` to change the options list.
- **No SirNukes** anywhere, in either version.
- **It bundles UI Extensions' menu code itself.** `subst_02.cat` replaces 20 vanilla menu files (`menu_map`, `menu_playerinfo`, `menu_toplevel`, `gameoptions`, `menu_interactmenu`, `helper` and more) with versions carrying kuertee's callback system (`uix_callbacks`, `function menu.registerCallback` in 10 of them). So SWI works without UI Extensions installed separately, which is why `content.xml` declares no dependency (only the game version and five DLCs). kuertee is one of SWI's listed authors, and SWI also bundles copies of several kuertee mods' UI code (reputations and professions, social standings, kill counts, emergent missions).
- **MD side** (0.90, unchanged from 0.86): opening Player Info or the Encyclopedia (`event_ui_triggered screen="'PlayerInfoMenu'"`) makes MD write the page data to `player.entity.$swiMaintenanceData`; while the menu is open, a 0.25 s cue sends `raise_lua_event 'swi.togglePlayerInfoMenuRefresh'` and the Lua re-reads the blackboard; on `menu_close` MD removes the data. Values from Lua arrive as `event.param3` (e.g. `AddUITriggeredEvent("kuertee_ssac", "transactionsByStation", list)`).
- **A Lua load handshake with no handler:** MD sends `raise_lua_event 'SWIUI_LoadLua'` with a module path, waits for `SWIUI_OnLoad`, and retries after 30 s. No handler was found in SWI's Lua, its replacement menus, or UI Extensions; it may be a leftover from an older loading method (loading happens through `ui.xml`).
- **SirNukes only for typed chat commands:** 62 listeners for SirNukes' `Chat_Window_API` text entry, all admin/debug commands (e.g. `debug em hunt cues`, `reset emissions`) that do nothing without it.
- **No player-facing settings.** The bundled kuertee mods keep hardcoded defaults in an MD `UserSettings` cue (reward multiplier, mission-offer distance, debug chances), re-applied on every start and load and exposed as `global.$kEMissions_UserSettings`. Changing them means editing the mod's files. No options registration of any kind (no SirNukes, no added options). Its only options-menu change is `sw_gameoptions.lua` *removing* the Timelines and tutorial entries.
- **Detection instead of choice:** the bundled kuertee mods detect SWI with `$IsSWIExists = @ware.tie_fighter != null` and switch to a reduced mode, our "detect, don't assume" pillar in practice.
- **Settings migration:** `<patch sinceversion="N">` blocks on the `UserSettings` cue update stored values in existing saves when the mod changes.

## The Lua ↔ MD bridge (vanilla)

| Direction | Mechanism | Vanilla use (9.00) |
| --- | --- | --- |
| MD → Lua, data | MD sets `player.entity.$name`; Lua reads `GetNPCBlackboard(playerId, "$name")` | `GetNPCBlackboard` 6× |
| MD → Lua, event | MD `raise_lua_event`; Lua `RegisterEvent` | 9× / 77× |
| Lua → MD | Lua `AddUITriggeredEvent("screen", "control", value)`; MD `<event_ui_triggered screen="'screen'" control="'control'"/>` | 122× / 565× |

SWI uses the same calls (e.g. `AddUITriggeredEvent("kuertee_ssac", "lua_loaded")`, `GetNPCBlackboard(playerId, "$swiMaintenanceData")`).

## Approach for our in-game settings

- **The options hook can add entries.** In SWI's bundled `gameoptions.xpl`, each registered callback receives the options list and returns a modified one (`options = uix_callback(options, config)`, ~line 9493). SWI uses it to filter; returning the list with our entries added is how our page would work. Vanilla's option entries are tables with `name`, `value` and `callback` functions (e.g. the `extensionsettings` entries in vanilla `gameoptions.lua`, ~line 1464), so we have a model.
- **This goes further than SWI**, which has no player-facing settings, and works for SWI players too, since SWI's bundled menus provide the same hook.
- **Use `<patch sinceversion="N">`** on our settings cue to migrate stored settings when they change.

- A Lua file loaded through our own `ui.xml` adds an "A Pirate's Life" section via `displayOptions_modifyOptions`.
- Current values reach Lua through the player blackboard; changes go back with `AddUITriggeredEvent("apirateslife", …)`, and MD updates the same globals the config file sets.
- **Unlike SWI:** don't bundle replaced vanilla menus. It's heavy, has to be redone every game patch, and can conflict with a separately installed UI Extensions; that's a total conversion's trade-off, not ours. Declare UI Extensions as an optional dependency and check that `registerCallback` exists before using it, so the mod still works (config file only) without it. That check also passes for SWI players, whose bundled menus provide `registerCallback`.
- To verify when building: whether extension Lua loads with Protected UI Mode on, and the exact shape of the options table `displayOptions_modifyOptions` receives (answered below).

## The options hook on 9.00 (2026-10-21)

Read from UI Extensions v9.0.0.18 (`content.xml` version 900, dated 2026-10-16; GitHub head `efc9151`, 2026-10-19) and vanilla 9.00 `ui/addons/ego_gameoptions/gameoptions.lua`.

- **Not installed on Erik's machine:** `extensions/kuertee_ui_extensions` is an empty folder left by Vortex (marker files only, no `content.xml`), so the game doesn't load it. Testing the page in game needs UI Extensions installed (Nexus 552 or the GitHub release).
- **9.00 support:** the changelog lists 9.0 compatibility from v9.0.0.1 (11 Jun 2026), with the 9.0 RC UI files merged, and regular fixes since.
- **The hook:** `menu.displayOptions(optionParameter)` (`gameoptions.xpl:9600`) runs every `displayOptions_modifyOptions` callback as `options = callback(options, config)` before drawing, for every page that goes through `displayOptions`, with `menu.currentOption` set to the page key ("main", "settings", "game", …).
  - `options` is the live `config.optionDefinitions[page]` table, not a copy: a callback that inserts into it adds the entry again on every redraw. Return a new table, as SWI does. SWI copies with `pairs`, which doesn't guarantee the order of the numbered entries; copy them with `ipairs` and the named fields (`name`, `info`, `warning`) separately.
  - `config` is the menu's whole config table, so a callback can also add a page of its own: `config.optionDefinitions["apirateslife"] = { … }`. `menu.submenuHandler` shows any page key that has an entry there (`elseif config.optionDefinitions[optionParameter] then menu.displayOptions(...)`), and the back arrow returns to the page that linked it.
  - `registerCallback` warns in the log for names not in `menu.uix_supportedCallbacks`; `displayOptions_modifyOptions` is in the list.
  - Also supported: `submenuHandler_customPage` (draw a whole page yourself) and `submenuHandler_preDisplayOptions`. Not needed for a list of options.
- **Option entries** (vanilla `menu.displayOption`, `gameoptions.lua:4856`): `id`, `name`, optional `mouseOverText`, `display()` (hide), `selectable()` (grey out). With a `value`, the row has a control chosen by `valuetype`:
  - `"button"`: `value()` returns the button text, `callback()` on click. Vanilla's on/off options use this with ReadText(1001, 2617)/(1001, 2618) ("On"/"Off").
  - `"slidercell"`: `value()` returns `{ min, max, start, step, suffix, … }`, `callback(value)` on every change.
  - `"dropdown"`: `value()` returns the entries and the current one, `callback(id, option)`.
  - Without `value`, a `submenu = "<page>"` entry links to another page.
  - Values are functions read on every frame, so a callback only needs to update what `value()` reads; no redraw.
- **Getting the menu:** `Helper.getMenu("OptionsMenu")`; SWI's `sw_gameoptions.lua` then calls `registerCallback` unconditionally. Our `ui.xml` lists `<dependency name="ego_gameoptions"/>` so our file loads after the options menu; without UI Extensions the menu has no `registerCallback`, which is the check for "UI Extensions present".
- **Protected UI Mode:** vanilla 9.00 only warns when an extension *modifies base-game UI files* (`GetUISafeModeOption()` with `C.GetModifiedBasegameUIFilesExtensions()`, `gameoptions.lua:444`, `:4066`). UI Extensions does, and kuertee recommends leaving the mode on and ignoring the prompt. A plain `ui.xml` add-on like ours modifies nothing: our game-test extension already loads its Lua this way.
- **Dependency order matters** (found in our first game-test run): an add-on's `<dependency>` entries load before it, in the order listed, and can pull a vanilla menu ahead of the vanilla files it relies on. The options menu's Lua uses types declared in `ego_detailmonitor` (`SoundInfo`, `UIMacroCount` in `menu_playerinfo.lua`), but vanilla's own `ego_gameoptions` lists only `ego_detailmonitorHelper`. So `<dependency name="ego_gameoptions"/>` on its own loaded a first copy of the options menu that failed part way (`declaration specifier expected near 'SoundInfo'`), and our file ran against it; X4 loaded the menu again later in its usual place, so the menu worked but our hook was missing. List `ego_detailmonitor` first. UI Extensions' own `ui.xml` has its dependencies commented out, likely for this reason.
- **No game means no page:** the options menu in the start menu has no player, so per-save settings can only be shown in game (`display = function () return not menu.isStartmenu end`).
