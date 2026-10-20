# Spec: Capture settings

Plan item: Phase 1, "Player settings for intact captures" · Status: Done

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
- [x] Test in game: each flag on and off via the config file (set with `deploy --set`)

## Done when

- Defaults (both on): captures arrive intact, and the log shows the config applied on load.
- Setting a flag to 0 in the config file and reloading restores vanilla damage for that case, logged as such.
- No errors from our scripts in the log.

## Test results (in game, 2026-10-20)

| Test | Settings | Ship | Result |
| --- | --- | --- | --- |
| 1 | eject off, claim on | Magpie (S container) | Pass: vanilla sabotage took the gun and both shields; log shows `takes vanilla damage`. Claim intact (vanilla max damage 92) |
| 2 | eject on, claim off | Kestrel (scout) | Pass: no sabotage; log shows `takes vanilla claim damage`. No equipment lost, as vanilla destroys each item only by chance, so the log is the evidence |
| 3 | defaults (both on) | Falcon (fighter), Kestrel (scout) | Pass: both fully equipped with hull unchanged; log shows `keeps its hull and equipment` and `claimed without damage` for each |

Every load logged `settings: config applied` with the deployed values, and our scripts logged no errors.

The game tests (`make game-test`) now cover all four cases automatically: `pilot_bail_intact`, `pilot_bail_vanilla_when_off`, `claim_intact` and `claim_vanilla_when_off` ([research note](../research/automated-game-testing.md#the-proof-of-concept)).

When checking for missing equipment, count a ship's slots by connection in its macro, not by tags: a missile launcher slot is also tagged `weapon`, so counting tags makes a scout look like it lost a gun.

## Open questions

- Shipping a template "user config" extension so file edits survive mod updates (a diff patch on our config from its own folder).
