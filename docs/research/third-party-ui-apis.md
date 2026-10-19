# Third-party UI APIs on X4 9.0

**Status: done for the settings decision (2026-10-19).** How mods add in-game UI on 9.0, which shared APIs are healthy, and how SWI does it. Led to the "Key decisions" UI rule in [PROJECT.md](../PROJECT.md#key-decisions).

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

Studied SWI 0.86 (X4 7.60, from the local 7.60 install) and 0.90 (X4 8.00, 2025-12-06; snapshot at `E:\x4-dev\reference\mods\swi-0.90\`, without the 18 GB asset file). Reference only, per the SWI etiquette in [DESIGN.md](DESIGN.md#design-pillars-and-compatibility-architecture).

- **Loading:** a `ui.xml` add-on (identical in both versions) lists loose Lua files under `ui/` and the vanilla menus they extend (`ego_gameoptions`, `ego_detailmonitor`, `ego_interactmenu`, `ego_detailmonitorhelper`).
- **Hooks:** UI Extensions' `registerCallback` everywhere: 28 uses across 9 of 10 files in 0.86, 40 in 0.90 (new ones include `createPlayerInfo_on_start`, `createInfoFrame_on_info_frame_mode`, `createFactionDetailsContext_on_before_detailtable`, `onRowChanged`, `onClearUIData`). `sw_gameoptions.lua` uses `displayOptions_modifyOptions` to change the options list.
- **No SirNukes** anywhere, in either version.
- **No declared dependency on UI Extensions** in `content.xml` (only the game version and five DLCs), yet its Lua calls `registerCallback` unguarded, so it relies on players installing UI Extensions separately. kuertee is one of SWI's listed authors, and SWI bundles copies of several kuertee mods' UI code (reputations and professions, social standings, kill counts, emergent missions).

## The Lua ↔ MD bridge (vanilla)

| Direction | Mechanism | Vanilla use (9.00) |
| --- | --- | --- |
| MD → Lua, data | MD sets `player.entity.$name`; Lua reads `GetNPCBlackboard(playerId, "$name")` | `GetNPCBlackboard` 6× |
| MD → Lua, event | MD `raise_lua_event`; Lua `RegisterEvent` | 9× / 77× |
| Lua → MD | Lua `AddUITriggeredEvent("screen", "control", value)`; MD `<event_ui_triggered screen="'screen'" control="'control'"/>` | 122× / 565× |

SWI uses the same calls (e.g. `AddUITriggeredEvent("kuertee_ssac", "lua_loaded")`, `GetNPCBlackboard(playerId, "$swiMaintenanceData")`).

## Approach for our in-game settings

- A Lua file loaded through our own `ui.xml` adds an "A Pirate's Life" section via `displayOptions_modifyOptions`.
- Current values reach Lua through the player blackboard; changes go back with `AddUITriggeredEvent("apirateslife", …)`, and MD updates the same globals the config file sets.
- **Unlike SWI:** declare UI Extensions as an optional dependency, and check that `registerCallback` exists before using it, so the mod still works (config file only) without it.
- To verify when building: whether extension Lua loads with Protected UI Mode on, and the exact shape of the options table `displayOptions_modifyOptions` receives.
