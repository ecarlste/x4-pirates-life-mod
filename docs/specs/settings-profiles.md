# Spec: Named settings profiles

Plan item: Phase 1, "Named settings profiles on the in-game settings page" · Status: Agreed

## Goal

On the settings page, the player saves the current values as a **named profile**, loads any profile into any save from a dropdown, picks the profile new games start from, and deletes profiles they no longer want. Profiles live in the player's X4 profile, so every save sees the same list. They replace the single "my defaults" set.

## Context

- Builds on the [in-game settings page](in-game-settings.md): per-save values in MD, seeding of new games from Lua when it reports in, the config file as the fallback. None of that changes.
- Asked for by Erik after the hand test of PR #37 (chat, 2026-10-22), like Bannerlord mods' settings profiles; design agreed in chat the same day.
- The options menu has what's needed (UI Extensions' `gameoptions.xpl`, same as vanilla 9.00):
  - **Dropdowns:** an option with `valuetype = "dropdown"`; `value()` returns the entries (`{ id, text, icon = "", displayremoveoption = false }`), the selected id and an optional override text; `callback(optionId, selectedId)` on a choice.
  - **Name entry:** `menu.displayUserQuestion(question, callback, negCallback, timer, waitforgfx, editboxHook, editboxNote)` shows a question with a text box when `editboxHook` is given (it returns the starting text); confirming calls `callback(text)`. Vanilla pushes the current page on `menu.history` first and the callback returns with `menu.onCloseElement("back")`.

## Design

- **Storage:** `__userdata_apirateslife = { profiles = { [name] = { <setting> = 0 or 1 } }, newGameProfile = name or nil }`, in the existing `userdata` saved variable. Lua only; MD never sees the list.
- **The page** (below the three switches):
  - **Save as profile…** opens a question with a name box, pre-filled with the profile last loaded or saved in this session (else the new-game profile). Saving under an existing name replaces that profile; the question says so. Names are trimmed, must not be empty and are at most 40 characters; a bad name saves nothing and the page says why.
  - **Load profile:** a dropdown of every profile, sorted by name. Choosing one copies its values into this save (MD event `LoadProfile`, the renamed `LoadDefaults`).
  - **Profile for new games:** a dropdown of "None (config file)" and every profile. A new game (or an old save meeting the settings for the first time) is seeded from it, exactly as "my defaults" was.
  - **Delete profile:** a dropdown of every profile; choosing one asks to confirm. Deleting the new-game profile sets new games back to none.
  - **Reset to config file values**, unchanged.
  - A status line under the actions says what the last action did ("Saved profile 'Hard mode'").
- **Migration:** a `defaults` set left by PR #37 becomes a profile named "My defaults" and the new-game profile, once.
- **No game test for the profile list itself.** It's Lua-only, and the game tests can only drive MD through UI events. The existing tests cover what MD sees: loading a profile (`LoadProfile`) and seeding from the new-game profile (`LuaLoaded`). The dialog, the dropdowns, deleting and migration are tested by hand.

## Tasks

- [ ] `ui/apirateslife_options.lua`: profiles, the four actions, status line, migration
- [ ] `md/apirateslife_settings.xml`: rename `LoadDefaults` to `LoadProfile`
- [ ] Game tests: send `LoadProfile`
- [ ] Hand test with UI Extensions

## Done when

Scenarios: [`tests/game/features/settings-profiles.feature`](../../tests/game/features/settings-profiles.feature).

- By hand: save two profiles with different values, load each into a save and see the switches follow; set one for new games and start a new game from it; delete one (and the new-game one: new games back to none); restart X4 and the profiles are still there; an empty name saves nothing.
- The game tests still pass.

## Open questions

- Sharing profiles between players (export/import) isn't possible from the options menu; X4's Lua can't write files. Later, if it's wanted.
