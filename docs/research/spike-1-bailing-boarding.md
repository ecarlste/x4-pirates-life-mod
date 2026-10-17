# Spike 1: How bailing and boarding work in vanilla

**Status: WIP.** Bailing is partly mapped below. Boarding and the adjacent topics haven't started. All references are to X4 9.00, unpacked under `E:\x4-dev\reference\x4-9.00\base\`.

## Hooks we need

From the design, our features have to be able to:

1. **Adjust a bail check:** change the chance that a target bails, based on notoriety, fear vs. honor, difficulty sliders, etc.
2. **Know when a ship bails:** both crew leaving and the pilot abandoning the ship (it becomes claimable).
3. **Capture with our assets:** ships on a pirating order claim what bails, without the player doing it by hand.

## Bailing (S/M)

### Where the decision is made

One cue makes every bail decision: `PlayerOwnedShipAttacks` in `md/notifications.xml` (line ~1184, `instantiate="true"`). Two things trigger it:

- **Being attacked:** the target's AI (`aiscripts/interrupt.attacked.xml`, ~line 276) signals `player.galaxy` with `param3='shouldwebail'` (`param` = attacker, `param2` = target).
- **A surrender demand:** the player's comms option in `md/conversations.xml` (`$surrenderoption` / `$maysurrender`, ~line 22; `g_surrender`, ~line 659). Both files carry "keep synced" comments. A `TODO` at ~line 660 notes that the surrender response doesn't yet consider ship strength or morale.

### How a check works (`notifications.xml`, ~lines 1244–1300)

- **Gates** (a check happens only if all pass): target `iscapturable`; shields below 20% (strict) or no shields; hull below 75%; not docked; not a capital ship without crew.
- **Cooldown:** one evaluated check per target pilot every **30 s** (`$target.pilot.$nextcapturechance`). Hitting faster doesn't add checks.
- **Surrender demands only:** also need `crew count / capacity < (16 − pilot morale) / 16`.
- **Eject chance:** `(46 − combinedskill/5)`, so 23–46%, then:
  - × target max hull ÷ attacker max hull, capped at 1 (attacking something bigger lowers the chance)
  - × (attacker shield% + hull%) ÷ (target shield% + hull%), capped at 1 (already 1 while you're healthy and the target is past the gates)
  - **÷ 4 if the attacker isn't the ship the player is personally flying** (wingmen and fleets get a quarter of the chance)
  - ÷ 2 for capital ships, ÷ 3 for Xenon
- **On success:** crew leave in batches of 1–3, sized by pilot morale (`eject_people`).
- **The pilot bails** (`$pilotbail`, ship left ownerless) only when that batch covers all remaining crew, the target isn't a capital ship or player-owned, **and** the attacker is player-owned *or* the attacker's `foundabandonedship` response is `'claim'` (~line 1293).

### Capturing

- Player-owned ships scan for abandoned ships (`aiscripts/interrupt.foundabandonedship.xml`) and respond according to each ship's **"found abandoned ship" setting** (`aiscripts/lib.respond.foundabandonedship.xml`); claiming runs `aiscripts/move.claim.xml`.
- That same setting feeds the pilot-bail condition above, so it affects whether a ship becomes claimable at all, not only who claims it.

### Play-tested technique (Erik)

Get the target's hull below 75%, then keep its shields under 20% with ion cannons, so the hull barely drops while the gates stay open. Each 30 s brings another check. Shields recovering to 25% closes the gate until they're knocked back below 20%.

## Candidate approach (to confirm)

- **One small diff patch** on `PlayerOwnedShipAttacks`, inserted after `$ejectchance` is computed: call our own library cue (`run_actions` with attacker, target and the vanilla chance, returning the new chance). All modifiers live in our code, and the vanilla patch stays small and stable.
- **The same patch raises our own MD signals** for "crew bailed" and "ship abandoned", with attacker and target. That gives every feature a galaxy-wide bail event; vanilla's `event_object_abandoned` needs a specific ship or group. These signals would become part of the integration contract.
- **Delegated capture** relies on the vanilla "found abandoned ship" response (set to claim) rather than reimplementing claiming.
- **Doubling the bail rate** (the mod's current goal) belongs in this patch too. `libraries/god.xml` has no bail value in 9.00, so the existing patch does nothing.

## Open questions

- Do NPC-vs-NPC attacks reach this cue, or only attacks involving the player? (The `shouldwebail` signal is sent for every attack, but the cue's name and comments suggest player-owned attackers.)
- Where is the "found abandoned ship" setting stored and set, and can an order set it per ship?
- Does the ÷4 for non-player-flown attackers make delegated raiding impractical without our multiplier?
- Exact behavior of `iscapturable`: which ships can never bail?
- Boarding (L/XL), cargo drop demands, faction reactions to theft, Yaki IFF disguise: not started.
