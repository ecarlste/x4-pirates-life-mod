# Spec: Capture settings

Plan item: Phase 1, "Player settings for intact captures" · Status: Agreed

## Goal

Players choose whether captured ships arrive intact, with two on/off settings: **intact when the pilot ejects** (no hull drop or sabotage) and **intact when marines claim** (no claim damage). On means our behavior; off means vanilla. Both default to on. This PR sets them from a config file; an in-game settings page through kuertee's UI Extensions follows as its own plan item.

## Context

- The two behaviors come from [capture without damage](claim-no-damage.md): insertions in our `md/notifications.xml` (`$damageminpercent` → 100, `$scuttle` → false) and `aiscripts/move.claim.xml` (`$damagemaxpercent` → 0).
- **Why not SirNukes' options menu** (built first, then dropped): his APIs haven't been updated since Dec 2025 and have 9.0 reports of red errors and "No menus registered". kuertee's UI Extensions is maintained and is what SWI builds its UI on, so in-game settings will use it. See PROJECT.md, "Key decisions".
- X4 mods can't read arbitrary files, so the "config file" is one of our own MD scripts.

## Design

- **Config file `md/apirateslife_config.xml`:** a commented library that sets the defaults in global variables (`global.$APiratesLife_IntactOnEject`, `global.$APiratesLife_IntactOnClaim`). It's re-applied on every game start and load, so edits apply after a restart. Its header explains the values, says in-game settings are planned, and warns that mod updates overwrite edits. Globals, because AI scripts can read them but can't call MD libraries.
- **Settings logic `md/apirateslife_settings.xml`:** applies the config on every start and load. The future in-game settings page will write the same globals.
- **Patches read the flags** and treat a missing value as on: `not (global.$X? and global.$X == 0)`. A missing setting never silently means vanilla, unlike Better Piracy's null config (bug 14 in the [prior-art note](../research/prior-art-better-piracy.md)).
- **Log** the applied values on each start and load.

## Tasks

- [x] `md/apirateslife_config.xml` and `md/apirateslife_settings.xml`
- [x] Gate the pilot-eject and claim insertions on their flags
- [x] Validate scripts and patches; check the patched files against vanilla
- [ ] Test in game: each flag on and off via the config file

## Done when

- Defaults (both on): captures arrive intact, and the log shows the config applied on load.
- Setting a flag to 0 in the config file and reloading restores vanilla damage for that case, logged as such.
- No errors from our scripts in the log.

## Open questions

- Shipping a template "user config" extension so file edits survive mod updates (a diff patch on our config from its own folder).
