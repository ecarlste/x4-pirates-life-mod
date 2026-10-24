# Spec: Settings profiles

Plan item: Phase 1, "Settings profiles: a game is on a profile or on its own settings" · Status: Agreed

## Goal

On the settings page the player picks a **profile** for the game: the built-in **Default** (the config file) or one they saved. A game on a profile follows it, including changes saved into it from other games. Changing a setting in a game marks it changed ("Hard mode \*") and stops it following the profile, until the player saves the changes into the profile or picks a profile again. Profiles live in the player's X4 profile, shared by every save; a game's own settings are saved with the game, like everything else in it.

## Context

- Replaces the profile behaviour built in PR #39 ([that version of this spec](https://github.com/ecarlste/x4-pirates-life-mod/blob/35ade88/docs/specs/settings-profiles.md)): there, loading a profile copied it into the save, and nothing followed a profile afterwards. Designed with Erik in chat, 2026-10-22 to 10-24.
- **The flows, with the data each step writes:** [settings-profiles-flows.md](settings-profiles-flows.md). It's the reference for behaviour; this spec doesn't repeat it.
- Builds on the [in-game settings page](in-game-settings.md): the page (UI Extensions' `displayOptions_modifyOptions`), the Lua ↔ MD events, the config file as the baseline, the tuning settings that only the config sets.
- Options-menu building blocks (dropdowns, the question with a text box) are listed in the [#39 version](https://github.com/ecarlste/x4-pirates-life-mod/blob/35ade88/docs/specs/settings-profiles.md#context) and already used by the page.

## Design

- **Three stores, each with one job** ([flows: stores](settings-profiles-flows.md#settings-profiles-flows)):
  - **Config file:** a default for every setting, and what "Default" means. Never written.
  - **X4 profile file** (the page's `userdata` saved variable): `profiles[name]` and `newGameProfile`. Written only when the player saves, deletes or picks for new games, never on load.
  - **Game state** (MD), saved with the game: `profile` (what the Profile dropdown shows: `"Default"`, a profile's name, or `null` for "None (custom settings)"), `modified`, and `inUse` (the values the game runs with).
- **How a game's settings are worked out, on every start and load:** config first, then the profile's current values for a game on a profile and not modified. A game saved while modified switches to None with its `inUse` (the profile may have changed since). A game whose profile is gone (deleted, another PC) switches to None with its `inUse`. A game on None keeps its `inUse`. The tuning settings always come from the config.
- **The page**, below the three switches:
  - **Profile** dropdown: Default (config file), then the saved profiles sorted by name; "None (custom settings)" appears only while the game is on None. While modified it reads "Hard mode \*".
  - **Save changes to 'Hard mode'**: enabled only while the game is modified and the dropdown shows a saved profile (not Default, not None). Writes `inUse` into that profile, clears `modified`, disables itself.
  - **Save as new profile…**: the only action that asks for a name; creates the profile from `inUse` and puts the game on it, leaving the previous profile as it was. An existing name asks "Replace …?". Names are trimmed, 1 to 40 characters, case-sensitive, and can't be "Default"; a refused name saves nothing and the status line says why.
  - **Profile for new games**: Default or a saved profile.
  - **Delete profile**: asks first; games on it switch to None with their values; "Profile for new games" falls back to Default if it was that profile.
  - A status line says what the last action did.
  - **Removed:** "Reset to config file values" (choose Default) and "Load profile" (the Profile dropdown).
- **Rules** (details and reasons in [the flows' decisions](settings-profiles-flows.md#decisions-not-drawn-above)):
  - Changing any setting sets `modified`; it lasts only until the game is next loaded.
  - Choosing a profile (including Default, or the same one again) reloads it from the config plus that profile and clears `modified`, asking first if the game is modified.
  - Unknown or invalid settings in a profile are ignored and logged and keep their config value; profiles are cleaned only when the player saves into them. Setting names are never reused.
- **Lua and MD:** the Lua page owns the X4 profile file; MD owns the game state and is the only writer of `inUse`. Page events (`AddUITriggeredEvent("APiratesLife_Settings", …)`): a setting change, "use this profile" with its values (or Default), "saved into the profile" (clears `modified`), "profile gone" (to None). MD mirrors `profile`, `modified` and `inUse` to the player blackboard for the page.
- **Saves from PR #37 and #39** hold `global.$APiratesLife_Chosen` (values chosen on the page) and no profile: on their first load they become None with `inUse` = config plus those values, or Default if nothing was chosen. The X4 profile file's `profiles` and `newGameProfile` keep their #39 shape; #37's `defaults` migration stays.
- **Testing:** MD behaviour (changes set `modified`, load rules, Default, invalid values) through game tests that send the page's events, as today. The page itself (dropdown labels, buttons enabling, dialogs, profiles surviving an X4 restart) is `@manual`. Game-test isolation for profiles: profiles created in the test game start are marked `test = true`; a run deletes marked profiles and copies the settings table first, cleans up after each test, and restores the copy at the end ([flows: decisions](settings-profiles-flows.md#decisions-not-drawn-above)).

## Tasks

- [ ] `md/apirateslife_settings.xml`: game state `profile` / `modified` / `inUse`, the load rules, the page events, migration of #37/#39 saves
- [ ] `ui/apirateslife_options.lua`: the Profile dropdown with Default and "\*", "Save changes to …", "Save as new profile…" rules, delete switching games to None; remove "Load profile" and "Reset"
- [ ] Game tests for the MD rules, and the test isolation for profiles
- [ ] Update the in-game settings scenarios that this changes (reset becomes choosing Default; changed settings no longer follow the config)
- [ ] Hand test of the `@manual` scenarios with UI Extensions

## Done when

Scenarios: [`tests/game/features/settings-profiles.feature`](../../tests/game/features/settings-profiles.feature). The game tests pass, and the `@manual` scenarios pass by hand.

## Open questions

- Sharing profiles between players (export/import) isn't possible from the options menu; X4's Lua can't write files. Later, if it's wanted.
