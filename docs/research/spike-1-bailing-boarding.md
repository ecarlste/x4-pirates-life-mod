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
- **The setting is a faction "signal" response** defined in `libraries/factions.xml`: `foundabandonedship`, with responses `claim`, `ignore` (the default), `mark` and `protect`. These are the per-ship and global behavior settings in the game's menus.
- **Scripts can set it per ship:** `<set_object_signal_response object="…" signal="'foundabandonedship'" response="'claim'"/>`. Vanilla uses the same action for other signals (e.g. `policehalt`). A pirating order can switch its fleet to `claim`, which both lets target pilots fully bail and gets the ship claimed.
- **`iscapturable`** (engine property, `libraries/scriptproperties.xml`): "Can this defensible be captured, either via signalleak (S/M sized) or via boarding (L+ sized). Additionally, for S-ships the pilot will not eject if it is not capturable." Scripts can change it with `set_object_capturable`, which vanilla story missions use.

### NPC-vs-NPC bails

NPC fights do run the bail check. When a ship is attacked by anything **not** player-owned, its AI (`interrupt.attacked.xml`, ~line 276) signals `'shouldwebail'` if it reacts (flees, fights back or calls for help). Player-owned attackers reach the cue directly through `event_player_owned_attacked_object`. The cue only needs attacker and target to have different owners, the attacker to be operational and not a spacesuit, and the target to be eligible.

The attacked ship's AI only reacts if its `attacked` signal response isn't `ignore`, it has a non-priority, non-critical order, and it isn't docked or on a highway. Every NPC attacker gets the ÷4, and the pilot only fully bails if the NPC attacker's `foundabandonedship` response is `claim`.

### Play-tested technique (Erik)

Get the target's hull below 75%, then keep its shields under 20% with ion cannons, so the hull barely drops while the gates stay open. Each 30 s brings another check. Shields recovering to 25% closes the gate until they're knocked back below 20%.

## Candidate approach (to confirm)

- **One small diff patch** on `PlayerOwnedShipAttacks`, inserted after `$ejectchance` is computed: call our own library cue (`run_actions` with attacker, target and the vanilla chance, returning the new chance). All modifiers live in our code, and the vanilla patch stays small and stable.
- **The same patch raises our own MD signals** for "crew bailed" and "ship abandoned", with attacker and target. That gives every feature a galaxy-wide bail event; vanilla's `event_object_abandoned` needs a specific ship or group. These signals would become part of the integration contract.
- **Delegated capture** relies on the vanilla "found abandoned ship" response (set to claim) rather than reimplementing claiming.
- **Doubling the bail rate** (the mod's original goal) belongs in this patch too. The old `libraries/god.xml` patch has been removed; see "Extension loading" below.

## Confirmed in game

From running the bail hook ([spec](../specs/bail-hook.md)) on X4 9.00, 2026-10-18:

- **NPC fights reach the bail check:** 72 checks were logged in one session, mostly NPC vs. NPC (e.g. `XEN Raiding Party N attacking HOP Fighter Squadron …: chance 10`).
- **Stations effectively never force bails.** Every check with a station as the attacker (defence platforms, factories) had chance 0, because the target-hull ÷ attacker-hull factor is tiny.
- **A player-flown attack:** the player's ship vs. an SCA Kestrel (S) got a vanilla chance of 38 (no ÷4); doubled to 76, the first roll succeeded about 64 s into the fight. One crew left and the pilot bailed, leaving the ship ownerless.
- **Scale Plate Pact as targets** (player reports, matching the game's station placement): SCA reputation is locked at −5, so attacking them costs nothing. Their ships disguise as other factions until scanned, and attacking an unscanned one costs reputation with the faction it's posing as. Players hunt them in Silent Witness XI/XII, Hewa's Twin V and Nopileos' Fortune. Ties into the Yaki IFF disguise and the design's forged-ID idea.

## Extension loading

Learned from the first in-game run (X4 9.00, 2026-10-17):

- **A library file without a `<diff>` root is merged, not ignored or swapped in.** The old `libraries/god.xml` (root `<god>`, containing a `<replace sel=…>`) was read as extra god data. Universe generation still completed normally, but every new game logged `The key name "replace" is not recognized in lookup GodDBXML` (and the same for `sel`). Library changes must be `<diff>` patches.
- **Unsigned files log signature warnings** (`Could not find signature file …\god.xml.sig`, `Failed to verify the file signature … (error: 14)`). This is normal for any mod and harmless.
- **`md.Setup.GameStart` fires twice when a new game starts** (two smoke test log lines, one per instance). Probably once for the main menu's background game and once for the real start; not confirmed.

## Open questions

- Does the ÷4 for non-player-flown attackers make delegated raiding impractical without our multiplier? (A design call once the bail hook exists.)
- Which ships are uncapturable by default? `iscapturable` is engine-side; we only know scripts can change it.
- Cargo drop demands: the vanilla `piratehalt` signal (`libraries/factions.xml`, default response `attack`) is how *player* ships respond to pirates' demands. Not yet traced.
- Boarding (L/XL), faction reactions to theft, Yaki IFF disguise: not started.
