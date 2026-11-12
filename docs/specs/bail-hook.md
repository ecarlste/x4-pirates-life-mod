# Spec: Bail hook

Plan item: Phase 1, "Bring back the mod's 2x bail rate as an MD diff patch" (the SWI build drops the 2x) · Status: Done

## Goal

Every bail check in the game passes through our code, which can change the chance, and every bail raises our own signal. Outside capture operations the hook returns the game's own chance unchanged; inside them it adds [bail pressure](bail-pressure.md). Later notoriety, fear vs. honor and difficulty sliders plug into the same hook.

**SWI build** ([#117](https://github.com/ecarlste/x4-pirates-life-mod/issues/117)): the mod loads after SWI, so both insertions land in SWI's Enhanced Bailing block, which replaces vanilla's `do_if $target.iscapturable` in `PlayerOwnedShipAttacks`. The flat x2 and the integer cast are gone: SWI's chances are fractional, often 0.5–2%, and the cast turned them into 0. The hook still signals every check to the capture metrics, which keep the decimals.

## Context

- Research: [spike-1-bailing-boarding.md](../research/spike-1-bailing-boarding.md). Every bail decision happens in `PlayerOwnedShipAttacks` (`md/notifications.xml`, ~line 1184), for player and NPC attackers alike.
- The roll is `<do_if value="true" chance="if not $testcheat? then $ejectchance else 100">` (~line 1275), right after vanilla's ÷4 / ÷2 / ÷3 modifiers.
- Crew leave via `eject_people` inside `<do_if value="$eject?">`; `$numcrewbailing` and `$pilotbail` say how many crew left and whether the pilot did, and the block then removes `$numcrewbailing` (~line 1325).
- Vanilla already signals `player.entity` with `'player_owned_forced_bail'` when a player-owned attacker forces a pilot out. That only covers player attackers and pilot bails.
- Prior art: Better Piracy *replaces* the base `$ejectchance` line ([prior-art note](../research/prior-art-better-piracy.md)).

## Design

- **Insert, don't replace.** A diff patch (`md/notifications.xml` in our extension) adds one `run_actions` call just before the roll. Vanilla's formula, gates and modifiers stay untouched, so vanilla changes and other mods' patches are less likely to break us. Rejected: replacing the formula (Better Piracy's approach), which forks vanilla logic we'd then have to keep in sync by hand.
- **Hook after vanilla's modifiers.** Our library receives the final vanilla chance plus attacker and target, and returns the new chance. All our modifiers then compose on top of vanilla's.
- **Logic lives in our script.** `md/apirateslife_bail.xml` holds the library (`AdjustEjectChance`) and the bail listener. The patch stays two small insertions; behavior changes happen in our own file.
- **One bail signal.** The second insertion, before `$numcrewbailing` is removed, calls our `Bailed` cue with `table[$attacker, $target, $crew, $pilot]`. That covers crew-only and pilot bails from any attacker. It becomes part of the future integration contract.
- **The game's chance, unchanged, for now.** Doubling it (`[chance × 2, 100].min`, as an integer) was the 9.x line's first version; the SWI build dropped it.
- **Selectors use exact attribute values**, each resolving to exactly one element in 9.00, checked against the unpacked game files.

## Tasks

- [x] `md/apirateslife_bail.xml`: `AdjustEjectChance` library and `Bailed` listener, both logging with the `[apirateslife]` prefix
- [x] `md/notifications.xml` diff: hook before the roll, signal before `$numcrewbailing` is removed
- [x] Check both selectors match exactly one element in 9.00, and validate our script against `md.xsd`
- [x] Deploy with `make deploy-local` and test in game

## Done when

Scenarios: [`tests/game/features/bail-hook.feature`](../../tests/game/features/bail-hook.feature).

- `debuglog.txt` shows `[apirateslife] bail check: … chance N -> N` for bail checks, and `[apirateslife] bailed: …` when crew or a pilot bail.
- No diff-patch errors for `md/notifications.xml` in the log.
- In game: harassing a target past the gates (hull < 75%, shields < 20%) produces bails, and the smoke test's "target bailed" notification (in the test extension, `tests/game/apirateslife_tests/md/apirateslife_smoketest.xml`) still fires on a pilot bail.

## Open questions

- Order relative to Better Piracy's replace if both are installed (likely moot if we declare it incompatible).
