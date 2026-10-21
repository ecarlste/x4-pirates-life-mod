# Spec: Capture without damage

Plan item: Phase 1, "Captured ships arrive intact" · Status: Done

## Goal

A captured ship arrives as the player left it. Neither the bailing pilot nor the claiming marine damages it: no hull loss and no destroyed weapons, turrets or shield generators. Claims cover both a marine the player sends and a ship claiming automatically through its "found abandoned ship: claim" response.

## Context

- Vanilla `aiscripts/move.claim.xml` (9.00), after a successful claim: `$damagemaxpercent = 100 − marine skill`. If above 0, the hull drops by up to that many points (at most 30, never below 1%), and a share of non-mandatory weapons, turrets and shield generators are destroyed, each with a `$damagemaxpercent` chance. The block exists twice: `attention min="visible"` (~line 115) and `min="unknown"` (~line 226).
- `move.claim` is run by the claiming marine; `aiscripts/lib.respond.foundabandonedship.xml` is the only other caller. So one patch covers manual and automatic claims.
- Prior art: Better Piracy removes the two damage blocks outright ([prior-art note](../research/prior-art-better-piracy.md)).
- When the pilot bails, vanilla's `PlayerOwnedShipAttacks` (`md/notifications.xml`) does more damage: `$damageminpercent = 100 − pilot skill` (~line 1296) drops the hull to about that percentage, and `$scuttle` (~line 1336, NPC pilots) makes the pilot sabotage up to *pilot skill ÷ 10* weapons, turrets and shield generators. It also removes part of the cargo.

## Design

- **Zero the value instead of deleting vanilla's code.** Insert `set_value $damagemaxpercent = 0` right after vanilla computes it, in both attention blocks. Vanilla's own `gt 0` check then skips all damage, and the patch keeps working if vanilla changes what the damage does. Rejected: removing the blocks (Better Piracy), which breaks if their structure changes.
- **The same pattern for the pilot bail:** our existing `md/notifications.xml` patch sets `$damageminpercent` to **100** and `$scuttle` to false right after vanilla sets them, so the hull stays where it is and vanilla skips the sabotage. **Not 0:** vanilla's `do_if $damageminpercent gt 0` has a `do_else` that destroys the ship (meant for a perfect-skill pilot scuttling it), so 0 blew up every bailed ship in our first test. Vanilla sets the hull to `min(current, value)`, so 100 keeps the current hull.
- **Check what vanilla does after every value we change**, including `do_else` branches, not just whether the patch applies. Both other values are safe: `$scuttle` and the claim's `$damagemaxpercent` are only read in a `do_if` with no `else`. The cargo removal stays for now, since cargo has its own design (forced drops, hot goods).
- **All marine claims, any ship size.** Abandoned L/XL ships use the same claim step (boarding occupied ships is a separate system), and claim damage is just as unwanted there.
- **Hardcoded 0 for now.** AI scripts can't call MD libraries (`run_actions` is MD-only), so a future difficulty slider would publish its value in a global variable that this patch reads.
- **Log each claim and pilot bail** (`[apirateslife] claim: …`, `[apirateslife] pilot bail: …`), including what vanilla would have done, for verification.
- **Sabotage may return through design:** for example, fear vs. honor could decide whether a pilot dares to sabotage. The insertion point is where that logic would go.

## Tasks

- [x] `aiscripts/move.claim.xml` diff, with selectors checked to match exactly one element each in 9.00, and validated against `aiscripts.xsd` and `diff.xsd`
- [x] Deploy with `make deploy-local` and test: send a marine to claim an abandoned S/M ship
- [x] `md/notifications.xml`: zero the pilot-bail hull drop and sabotage, with selectors checked and the patched file validated
- [x] Test: force a pilot bail and check the ship keeps its hull and weapons

## Done when

Scenarios: [`tests/game/features/intact-captures.feature`](../../tests/game/features/intact-captures.feature).

- The log shows `[apirateslife] claim: <ship> claimed without damage (vanilla max damage N)` and `[apirateslife] pilot bail: <ship> keeps its hull and equipment …`.
- A captured ship's hull and equipment are the same as when the pilot bailed, and unchanged by the claim.
- No diff-patch errors for `move.claim.xml` or `notifications.xml` in the log.

## Open questions

- Whether bailing pilots should sabotage again later, decided by fear vs. honor.
