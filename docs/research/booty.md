# Booty: handing prizes to pirate factions

**Status: WIP.** The agreed design is in [DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing). This note holds the data behind it, the checks still to make in game, and the ideas we're still iterating on. References are to X4 9.00 unpacked under `E:\x4-dev\reference\x4-9.00\`.

## What scripts can read

- **A ship's value:** `$ship.value`, "the current value of this object, including value of units and upgrades" (`base/libraries/scriptproperties.xml:241`). Vanilla's ship sale uses an engine function, `GetTotalValue(ship, true, shipyard)` (`base/ui/addons/ego_detailmonitor/menu_map.lua`, `createSellShipsContext`), which isn't visible in the Lua files. Whether `.value` already counts hull damage and cargo is to check in game; if not, we add hull % × value and each cargo ware's amount × average price ourselves.
- **Who made a ship:** `makerraces`, the maker race list (`scriptproperties.xml:183`). Used for the pirates' tastes.
- **Fitted equipment:** `weapons`, `turrets`, `shields` with `.operational.list`, and `.macro.ware` (`scriptproperties.xml:531-548`, macro datatype from line 2070).
- **Moving the pilot to a marine slot:** vanilla's "work somewhere else" reassignment does it (`base/md/conversations.xml:1300-1330`: `set_entity_role`, `create_npc_template` on the new ship). Erik's experience: the transfer takes longer the farther apart the ships are, shows no pod, and survives selling the source ship.

## Ship values by size

Hull prices from every `wares.xml` (base and DLCs; ship wares only, no drones, spacesuits or story ships). Fitted value adds, for every weapon, turret, shield and engine slot in the ship's component file (slot type and size from the connection `tags`), the median price of equipment of that type and size (mining and deprecated items excluded).

| Size | Ships | Hull median | Fitted median | Fitted mean | Fitted ÷ hull |
| --- | --- | --- | --- | --- | --- |
| S | 81 | 164k | 502k | 565k | 3.5× |
| M | 70 | 300k | 803k | 1.27M | 2.2× |
| L | 67 | 3.1M | 5.4M | 7.2M | 2.0× |
| XL | 37 | 12.0M | 14.4M | 17.4M | 1.2× |

- These assume mid-priced gear in every slot. NPC ships often carry mk1 gear or have empty slots, so real prizes are often worth less; `$ship.value` in game is the real number.
- M's median is pulled down by cheap transports and miners; M warships are nearer the mean.

## Capture times

From first shot to the ship being abandoned, player-flown:

- **Seen:** two SCA S ships with the mod's old ×2 bail chance, 63 s (Riot Squad Kestrel) and 80 s (Marauder Falcon), from Erik's `debuglog.txt` on 2026-10-20; the [spike 1 note](spike-1-bailing-boarding.md#confirmed-in-game) has a third Kestrel at about 64 s. No M ship has been timed.
- **Model:** each successful bail check throws out 1–3 crew, and the pilot only bails on the success that empties the ship ([spike 1](spike-1-bailing-boarding.md#bailing-sm)). Vanilla checks every 30 s at about 36% for an average pilot. Crew capacity from the ship macros: S fighters 0–3, M corvettes about 6, M miners about 8, M frigates about 15, M transports about 17.

| Prize | Vanilla checks | With the planned bail pressure (10 s ticks rising to 80%) |
| --- | --- | --- |
| S fighter (1 success) | ~2 min | ~1 min |
| M corvette or miner (~2–4 successes) | ~5–6 min | ~2–3 min |
| M transport (up to ~8 successes) | ~10–12 min | ~3–4 min |

Capture is the small part of a prize's time. Rough full cycles, including finding the target and bringing the prize in: **S ~8 min, M ~20 min, L ~1 h** (L needs boarding, not built yet). Real numbers will come from the [capture metrics](../specs/capture-metrics.md) logging.

## Levels and thresholds

Targets for one faction, if that's all the player works on (agreed 2026-10-26):

| Milestone | Target playtime | Prizes at the cycle times above | Standing needed (cumulative, from fitted medians) |
| --- | --- | --- | --- |
| Level 1: M turn-ins open | ~2 h | ~15 S | ~5–7M |
| Level 2: L turn-ins open | ~8 h | + ~18 M | ~20M |
| Level 3: XL turn-ins open | ~25 h | + ~17 L | ~110M |
| Everything in that faction's store | ~50 h | XL prizes from there | to set with the store |

Standing counts booty after the stolen bonus, the faction's taste multiplier and the standing gain setting. The thresholds are settings, to be re-worked from real `.value` numbers and capture times once the metrics exist.

## To verify in game

- Does `$ship.value` already count hull damage? Does it include cargo?
- Does a crew transfer finish after its source ship has been handed over?
- How does `makerraces` read for ships with more than one maker?
- Can Xenon ships be captured in vanilla? They have no crew; the bail code divides the chance by 3 for Xenon, so some path exists.
- Which pirate stations can dock each size, and can the player dock there at their current relation? The Yaki start at −25 (enemy), which blocks docking.

## Still iterating

- **Drop points.** Some handovers happen at a drop point in space instead of a station: a pirate pickup crew (a tug or escort for big prizes) meets you there. Sometimes the authorities show up, and you defend the crew and the prize for a bonus. No station guns, so the fights are real; XL handovers are the set pieces. Heat should drive how often the authorities come. Still open: whether the pirates or the player choose drop point or station. Vanilla prior art: the "Retrieve Dead Drop" mission chain, including a "Military Police Inspection" variant (`base/md/gmc_retrieve_dead_drop.xml:1826`).
- **Finding the traitor.** If the authorities come because someone sold out the drop, the leak is a person (a contact, the pickup crew, your own crew, a rival). Clues from the ambush lead to a short hunt; what you do with the traitor is fear vs. honor; a traitor who gets away can come back.
- **Hailing the station manager.** Dock the prize, then hail the station and pick from a list of eligible docked ships, reverse-engineering style. Lets the player move the pilot by hand first. A later enhancement to the order.
- **Pirate versions of Xenon gear,** made the same way as the pirated gear in [pirate-refitting.md](pirate-refitting.md#raid-a-faction-arm-from-its-enemies).
- **End-game booty uses,** once a faction's store is fully unlocked.
