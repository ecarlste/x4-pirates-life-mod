# Spec: Claim without damage

Plan item: Phase 1, "Marines claim ships without damaging them" · Status: Agreed

## Goal

When a marine claims an abandoned ship, the ship arrives intact: no hull loss and no destroyed weapons, turrets or shield generators. This applies whether the player sends the marine or a ship claims automatically through its "found abandoned ship: claim" response.

## Context

- Vanilla `aiscripts/move.claim.xml` (9.00), after a successful claim: `$damagemaxpercent = 100 − marine skill`. If above 0, the hull drops by up to that many points (at most 30, never below 1%), and a share of non-mandatory weapons, turrets and shield generators are destroyed, each with a `$damagemaxpercent` chance. The block exists twice: `attention min="visible"` (~line 115) and `min="unknown"` (~line 226).
- `move.claim` is run by the claiming marine; `aiscripts/lib.respond.foundabandonedship.xml` is the only other caller. So one patch covers manual and automatic claims.
- Prior art: Better Piracy removes the two damage blocks outright ([prior-art note](../research/prior-art-better-piracy.md)).
- Separate from the damage vanilla applies when a pilot bails (`$damageminpercent` / `$scuttle` in `PlayerOwnedShipAttacks`), which isn't covered here.

## Design

- **Zero the value instead of deleting vanilla's code.** Insert `set_value $damagemaxpercent = 0` right after vanilla computes it, in both attention blocks. Vanilla's own `gt 0` check then skips all damage, and the patch keeps working if vanilla changes what the damage does. Rejected: removing the blocks (Better Piracy), which breaks if their structure changes.
- **All marine claims, any ship size.** Abandoned L/XL ships use the same claim step (boarding occupied ships is a separate system), and claim damage is just as unwanted there.
- **Hardcoded 0 for now.** AI scripts can't call MD libraries (`run_actions` is MD-only), so a future difficulty slider would publish its value in a global variable that this patch reads.
- **Log each claim** with `[apirateslife] claim: …`, including the damage vanilla would have done, for verification.

## Tasks

- [x] `aiscripts/move.claim.xml` diff, with selectors checked to match exactly one element each in 9.00, and validated against `aiscripts.xsd` and `diff.xsd`
- [ ] Deploy with `make deploy-local` and test: send a marine to claim an abandoned S/M ship

## Done when

- The log shows `[apirateslife] claim: <ship> claimed without damage (vanilla max damage N)`.
- The claimed ship's hull and equipment are the same before and after the claim.
- No diff-patch errors for `move.claim.xml` in the log.

## Open questions

- Whether to also stop the damage vanilla applies when the pilot bails (`$scuttle`), which Better Piracy offers as an option.
