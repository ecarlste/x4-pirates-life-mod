# Prior art: Better Piracy

**Status: WIP.** Features, vanilla hooks and the 9.x port are mapped; the Harass mission and Corsair order are only skimmed.

**Read only.** The original repository has no license, so none of this code can be copied into our mod. We study what it does and how, then write our own.

## Versions

| Version | Where | Target | Notes |
| --- | --- | --- | --- |
| Better piracy (original) | [GitHub](https://github.com/AlbertoRota/x4-Better-piracy), [Workshop 2056100433](https://steamcommunity.com/sharedfiles/filedetails/?id=2056100433), [Nexus 491](https://www.nexusmods.com/x4foundations/mods/491) | 3.x | By AlbertoRota. Author declared it dead (Mar 2025). |
| Better Piracy Reforged | [Nexus 2046](https://www.nexusmods.com/x4foundations/mods/2046) | 8.00 | Fork, v8.00.3 (Apr 2026). Now hidden by its author as unsupported. |
| **Better Piracy Reborn** | Steam Workshop 3816572322 | **9.x** | By Jayseun, v14.10 (2026-10-09). Ports fixes from a 7.0 maintenance fork. Requires SirNukes' Mod Support APIs. |

Local snapshots (not in git): `E:\x4-dev\reference\mods\better-piracy-original\` (git clone) and `…\better-piracy-reborn-14.10\unpacked\` (Workshop catalog unpacked with XRCatTool). X4 installs Workshop mods straight into the game's `extensions\` folder, and Reborn ships as `ext_01.cat`/`.dat`.

Reborn credits two more mods as inspiration, which are worth studying too: **True Capture** (vx) and **FixBailChance** (Kevrlet).

## Features

| Feature | How |
| --- | --- |
| **Harass** replaces vanilla's "Surrender!" | Right-click action (SirNukes' Interact Menu API) that starts a player mission in phases: damage shields → damage hull → chase → wait for surrender → claim. Works on S/M (force a bail) and L/XL (soften before boarding). |
| **Pirate gang** | The player's subordinates join a Harass and avoid killing the target. |
| **Corsair** order | Default order for 3-star pilots: patrol an area, pick targets from gravidar scans by size (S/M) and purpose (trade, mine, fight), then Harass them. |
| **Own bail logic** | `PlayerOwnedShipHarass` (in `md/betterpiracy_custom_bail_logic.xml`), a stripped-down copy of vanilla `PlayerOwnedShipAttacks` that skips vanilla's gates; chance = base × pilot morale × shield/hull × capital-ship factor. On a bail it clears the target's orders (`Wait`), removes its cargo, and optionally damages hull and components. |
| **Config menu** | 20+ options (bail chance, keep-pressure timer and range, crew thresholds, damage on bail…) via SirNukes' Simple Menu API. |
| **"Piracy is a crime"** | Advertised, but **disabled in the code** in every version, Reborn included ("Reputation hit disabled until I find a proper way of handling it"). Piracy has no consequences. |
| Claim and feedback tweaks | Marines claim without orbiting the target or causing extra damage; notification when crew bail. |

## How it hooks vanilla

All of Reborn's selectors resolve to exactly one element in 9.00 vanilla (checked against the unpacked files), so its patches should apply cleanly.

| Vanilla file | Patch |
| --- | --- |
| `md/notifications.xml` (`PlayerOwnedShipAttacks`) | **Replaces** the first `$ejectchance` line (the base formula): drops the hull-size ratio, makes the base configurable. The ÷4 / ÷2 / ÷3 modifiers remain. Adds a crew-bailed notification, an option to skip extra hull damage, and an option to skip component destruction after a pilot bail. |
| `md/conversations.xml` (`DefaultComm`) | Removes the two Surrender choices (`g_surrender`, `g_surrender_nope`). |
| `aiscripts/move.claim.xml` | Removes the marines' extra damage and the orbiting around the target. |

## What the 9.x port changed

About 75 changed lines in total; a maintenance port, not a rewrite:

- Patch points moved for newer vanilla bail logic (`$damageminpercent`, `$scuttle and $target.exists`, `$damagemaxpercent gt 0`).
- The Surrender patch removes only the two choices instead of the whole block (the old one broke other dialog).
- The flee-to-allied-station override was dropped, because the base game now does it.
- Corsair now respects its purpose filter; Harass missions are typed `raid`; config minimums are clamped (≥ 1 km range, ≥ 5 s between bail checks); optional bail damage no longer destroys the ship.

## Compatibility with A Pirate's Life

- **Same vanilla cue.** Both mods patch `PlayerOwnedShipAttacks`. Ours plans to *insert* a hook after the `$ejectchance` line, and theirs *replaces* that line. The replaced element keeps `name="$ejectchance"`, so our selector may still find it and both could apply, depending on load order. Unverified.
- **Surrender.** They remove vanilla's comm option; our design may keep or extend it.
- We're likely to declare it incompatible, since we aim to be the one piracy mod. Even so, our patches should fail gracefully rather than break the game when it's installed.

## Where we differentiate

- **Consequences.** Notoriety, heat, fear vs. honor and bounty hunters, where Better Piracy has none.
- **Use vanilla's rules, then adjust them.** We plan to keep vanilla's gates and add our modifiers through one small hook, rather than bypassing vanilla with a copied cue that has to be kept in sync by hand.
- **A full career and economy**: fencing, hot goods, hideouts, lane taxes, redemption.
- **Profile-driven** support for total conversions (SWI) and a public integration contract with signals for other mods.

## Ideas worth considering (to design our own way)

- An explicit player action to pressure a target is less random than vanilla's one-shot Surrender. It could be our take on "threaten / disable".
- Subordinates holding fire to avoid kills, which matches our wingman capture commands.
- Corsair's target filters (size, purpose) and "keep pressure" range and interval, for Raid Sector.
- Clearing the bailed ship's orders so it doesn't fly off, and a crew-bailed notification.
- Marines claiming without extra damage.

## Open questions

- How exactly Corsair hands a target to Harass (signal through `player.entity`), and its reported "flies around but does nothing" bug.
- What True Capture and FixBailChance do differently.
