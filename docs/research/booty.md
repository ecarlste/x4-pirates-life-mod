# Booty: handing prizes to pirate factions

**Status: WIP.** The agreed design is in [DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing). This note holds the data behind it, the checks still to make in game, and the ideas we're still iterating on. References are to X4 9.00 unpacked under `E:\x4-dev\reference\x4-9.00\`.

## What scripts can read

- **A ship's value:** `$ship.value`, "the current value of this object, including value of units and upgrades" (`base/libraries/scriptproperties.xml:241`). Vanilla's ship sale uses an engine function, `GetTotalValue(ship, true, shipyard)` (`base/ui/addons/ego_detailmonitor/menu_map.lua`, `createSellShipsContext`), which isn't visible in the Lua files. Booty uses the sale's own price (`GetTotalValue`, through our Lua), so whether `.value` counts damage no longer matters for it. The sale price does count hull damage (below).
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

Targets for one pirate group, if that's all the player works on (agreed 2026-10-26). Since 2026-10-27 there are more levels than these, several per size tier, opening unlock tiers too; the size milestones stay the time targets:

| Milestone | Target playtime | Prizes at the cycle times above | Standing needed (cumulative, from fitted medians) |
| --- | --- | --- | --- |
| M turn-ins open | ~2 h | ~15 S | ~5–7M |
| L turn-ins open | ~8 h | + ~18 M | ~20M |
| XL turn-ins open | ~25 h | + ~17 L | ~110M |
| Everything that group offers unlocked | ~50 h | XL prizes from there | to set with the unlock list |

Standing counts booty after the stolen bonus, the group's taste multiplier and the standing gain setting. The thresholds are settings: we build with these defaults and tune them from the capture-metrics logs and playtesting.

## Unlocks in the build menus

Erik's decision (2026-10-27): no store with its own stock. Booty buys an unlock, one ship or weapon at a time, from the group's representative (like vanilla's faction HQ window for licences and blueprints); standing decides which unlocks are offered. The unlocked ship or item can then be bought with credits in the group's wharf or shipyard's normal menus, at the vanilla base price times a multiplier. Locked ones still show, with the reason. Whether the game allows that per player is the spike in the plan. A faction of our own to sell the variants is the last resort.

### Spike findings (2026-10-27, game files only)

**Best route: one hidden research ware per unlock.** The game already gates ships and equipment per player by research, with exactly the "show it, say why" behaviour Erik wants:

- **A ware can need research.** Its `<production>` lists research wares (`<research><ware ware="research_…"/></research>`). Tides of Avarice's Erlking does this: `ship_pir_xl_battleship_01_a` needs `research_erlking_core` (`ego_dlc_pirate/libraries/wares.xml:475`). Equipment mods use it too (`mod_weapon_damage_01_mk1` needs `research_mod_weapon_mk1`).
- **The build menu shows it locked, with the reason.** `menu.checkLicence` (`base/ui/addons/ego_detailmonitor/menu_ship_configuration.lua:7222`) decides for every ship and piece of equipment in the menu. For a ware with research precursors it checks `HasResearched` and, if missing, colours the entry red and lists the research under "Required research:" (text 1026/8023). The entry still shows, like a ship without its licence. The research ware's name is ours, so it can say what to do, e.g. "Scale Plate standing level 3: unlock with booty".
- **MD grants it per player.** `<add_research ware="…"/>` and `<remove_research ware="…"/>` (the Erlking story, `ego_dlc_pirate/md/story_research_erlking.xml:527,542`; `base/md/diplomacy.xml:240`). Buying the unlock is then one action.
- **It stays out of the HQ research tree.** Research wares tagged `hidden` (`tags="hidden research"`, e.g. `research_module_build`) are skipped by the research menu (`menu_research.lua:99`, which excludes the `hidden` tag).
- **It's all data, with no Lua.** That means no UI Extensions needed and no menu code to break on game updates; for each variant, a diff on `wares.xml` adds the research ware and the precursor, which the generator script can write. Each unlock is one item.
- **Where it's sold:** a station's build list comes from the ware's `<owner faction="…"/>`, so variants owned by a group's factions show up at that group's wharfs and shipyards. The Vigor Syndicate (`loanshark`) already sells eight ships of its own, from an S transport (`ship_pir_s_trans_container_01_a`, general-use licence) to L miners.
- **Licences:** `checkLicence` skips the licence check for a ware that needs research (the two are an if/else), so a variant needing research isn't blocked by Scale Plate's locked −5 in the menu. Confirmed in game (below): with the unlock, a military-licence ship can be bought below +10.

**Other routes (fallbacks):**

- **Licences from the group's faction.** Our pirate-modified wares are owned by the group's faction and restricted by a licence type; reaching a level grants the player that faction's licence with `add_licence` (`licencefaction` sets whose licence it is; vanilla grants Hatikvah's station licences this way, `base/md/playerreputation.xml:100`). Licence types are a fixed list (`base/libraries/common.xsd:4402`), so this gives a few tiers per faction, not one unlock per item, and would also open that faction's vanilla gear.
- **Hiding locked wares in the menus** through kuertee's UI Extensions: per item, but needs Lua, the hook, and shows everything without UI Extensions.
- **Our own refit service** with `apply_loadout`: works without UI changes, but isn't the vanilla build menu.

### Proof of concept in game (2026-10-27)

Branch `spike/unlock-research-poc` (not merged; the code stays there for reference): a hidden research ware of ours (`research_apirateslife_poc`, `tags="hidden research"`) added as a precursor to two Vigor ships, the S container transport (general-use licence) and the S fighter (military licence), with a spike-only comm choice to grant or remove it. Erik checked it at the Vigor wharf, below +10 with Vigor:

1. **Locked:** both ships show in the Buy Ships list in red, with our text under "Required research:". ✔
2. **Unlock:** after `add_research`, both can be bought. ✔ Not yet confirmed: a purchase built and delivered to the end.
3. **Licence:** the military-licence fighter can be bought with the unlock while below +10, so the research replaces the licence check in the menu. ✔ This is what we want: standing gates our rewards whatever vanilla rep is.
4. **Hidden:** the unlock doesn't appear in the HQ research tree (the only unresearched entry Erik saw was vanilla's "Xenon Special Equipment"). ✔
5. **Save and load:** the unlock survives. ✔
6. **Removing:** `remove_research` locks both ships again. ✔

SWI gates its factions' special ship versions with research (in its normal research tree; see the SWI comparison below), so the mechanism is a familiar one for conversions too. SWI also marks those ships with a star in the Buy Ships dropdown. That's vanilla's own research icon (`gamestart_custom_research`, `base/libraries/icons.xml:772`), which `checkLicence` gives every research-gated ware in vanilla (`menu_ship_configuration.lua:7266`) and in SWI's replacement menu alike (`subst02/ui/addons/ego_detailmonitor/menu_ship_configuration.xpl:7152`). So our unlockable ships get the same marker with no work. To confirm on the next visit: whether the proof-of-concept ships showed it.

**Result: one hidden research ware per unlock is the way to build booty unlocks.** The other routes are no longer needed.

**Licences (Erik, 2026-10-27): our variants are gated by research only.** A first decision kept the vanilla licence on top, enforced by the mod; it was dropped the same day, because taking the research back on a lost licence would also stop the player building the variant at their own wharf, and the research gates both. Instead rep decides where the player can buy (an enemy group won't let them dock or trade), the research is never taken back, and vanilla's own wares keep every licence gate. So nothing has to catch a lost licence, and each unlock's research name only has to say what the unlock needs, which the generator writes per item.

**SWI for comparison (0.90):** its research-gated ships (the XXL Executor, Bellator, Praetor, Subjugator, MC85, TIE Silencer) use ordinary research in the visible HQ tree, named plainly ("TIE Silencer Prototype"). They still declare a licence (`capitalship`), which the menu skips, and no SWI script checks it. They're also tagged `blueprintsaleonly`, which locks them at every station the player doesn't own (`checkLicence`, text 1026/8019): they're built from blueprints at the player's own yards, never bought.

## To verify in game

Deferred until booty v1 can hand a ship over (agreed 2026-10-26): the checks below, and the capture-metrics check that a real capture's log turns into a CSV row, are done then, comparing `.value` with the Vigor Syndicate wharf's sale price for different ships.

- ~~Does the price count hull damage?~~ **Yes, on the hull's own price only** (Erik's game, 2026-10-27, PR #63). The same pirated Argon Nova Vanguard (TGW-894) was handed to Vigor twice from one save: at 2316/3100 hull (74.7%) the sale price was 1,147,330 Cr, and repaired to 100% it was 1,181,604 Cr, up 34,274 Cr (3%). That fits a hull price of about 135k scaled by hull %, with the ~1.05M of equipment untouched. So an intact prize is worth more, but for a fitted fighter only a little: its equipment is most of the price.
- **No comms with Vigor stations** (Erik's game, 2026-10-27): the interact menu of two Vigor stations has no Comm entry at all, even from inside the hangar, and the comm hotkey does nothing, while Vigor ships can be hailed. The menu's actions come from the engine (`menu_interactmenu.lua` only shows them), and nothing in Tides of Avarice was found that turns station comms off, so it looks like vanilla X4 doesn't hail NPC stations (X3 did; X4 offers "Request docking permission" instead). Not checked at another faction's station. Booty doesn't need it: the manager or ship trader in person offers the handover.
- **Comm with a station's people from the map** (the station's people list, right-click a person, Comm) needs the station's `operator_name` info, unlocked at 60% of its information (`base/libraries/infounlocklist.xml:25`; `menu_map.lua:26152`, `:26243`); before that their names show empty and Comm is disabled. Erik's Vigor wharf was at 18%, still under it after scanning. The station's secrecy level caps each scanner level (e.g. secrecy 2: 33% at scan level 0, 66% at level 1), so passing 60% may need a better scanner or the station's data leaks. Once Erik got the wharf past 60%, he could comm both the manager and the ship trader from the map's crew list, and both offered "Hand over booty" (2026-10-27). Erik normally plays with a mod that skips station scans, "Skip Station Scan".
- ~~Does the sale price include cargo?~~ **Yes** (Erik's game, 2026-10-27): the same Nova's vanilla Sell Ships price went from 1,147,330 Cr to 1,148,390 Cr after it bought 40 water, +1,060 Cr or 26.5 Cr a unit: exactly half water's average price (53 Cr; its range is 32–74, `base/libraries/wares.xml`). So a prize's cargo is paid for too, at about half its average price, and earns booty with the rest. One ware checked; others may differ.
- `.value` (capture metrics) for comparison: a fully fitted Nova Vanguard read about 1.6–2.1M, above its sale price of about 1.2M, so `.value` and the sale price differ.
- Does a crew transfer finish after its source ship has been handed over?
- How does `makerraces` read for ships with more than one maker?
- Can Xenon ships be captured in vanilla? They have no crew; the bail code divides the chance by 3 for Xenon, so some path exists.
- Which pirate stations can dock each size, and can the player dock there at their current relation? The Yaki start at −25 (enemy), which blocks docking.
- At what relation does Vigor stop the player docking and trading, and does the buy menu itself refuse an enemy faction's station? That's what keeps a player at war with Vigor from buying its variants.
- Do variants owned by Vigor turn up in Vigor's own NPC ships and loadouts? If so, decide whether that's wanted.
- A purchase of an unlocked variant built and delivered to the end, and the research star icon on it in the Buy Ships list (not yet seen on the proof-of-concept ships).

## Still iterating

- **Drop points.** Some handovers happen at a drop point in space instead of a station: a pirate pickup crew (a tug or escort for big prizes) meets you there. Sometimes the authorities show up, and you defend the crew and the prize for a bonus. No station guns, so the fights are real; XL handovers are the set pieces. Heat should drive how often the authorities come. Still open: whether the pirates or the player choose drop point or station. Vanilla prior art: the "Retrieve Dead Drop" mission chain, including a "Military Police Inspection" variant (`base/md/gmc_retrieve_dead_drop.xml:1826`).
- **Finding the traitor.** If the authorities come because someone sold out the drop, the leak is a person (a contact, the pickup crew, your own crew, a rival). Clues from the ambush lead to a short hunt; what you do with the traitor is fear vs. honor; a traitor who gets away can come back.
- **Hailing the station manager.** Now one of the two ways in for v1 (with the order); still open: the flow. Dock the prize, then hail the station and pick from a list of eligible docked ships, reverse-engineering style. Lets the player move the pilot by hand first.
- **What pirates do with the ships.** In v1 a handed-over ship goes the way of a ship sold at that station. Later, maybe: the group flies it (its fleet really grows; needs a spike on ownership changes, orders and a cap) or strips it for parts.
- **Group missions and tips,** gated by standing: pirate-side missions like SWI's bounty-hunter missions, and tips on targets.
- **A bypass quest line** for groups whose stations the player can't reach at first (e.g. a faction locked behind a story or terraforming), switchable in the config.
- **Unlocking a family of items at once,** for a price that adds up to about the same as buying each; single unlocks let the player buy only what they want.
- **Notoriety favours:** at random, a group adds extra money to a handover to buy a famous pirate's favour.
- **More groups after Vigor** (v1 is Vigor only, agreed 2026-10-27). The Riptide Rakers could be the honorable path, with Vigor as the notorious one; the Yaki wharf adds S/M in Savage Spur I. SCA has no wharf or shipyard, so it would either not be a group or sell its unlocks at another group's stations.
- **Earning past a locked relation.** MD can unlock a faction's relations, set them and lock them again, as Scale Plate's terraforming milestone does (`set_faction_relation_locked`, `base/md/terraforming.xml:2318`). A standing reward or a quest line could do the same for SCA.
- **Pirate versions of Xenon gear,** made the same way as the pirated gear in [pirate-refitting.md](pirate-refitting.md#raid-a-faction-arm-from-its-enemies).
- **End-game booty uses,** once a group's unlocks are all bought. Related: the pirate-lord ideas (your own faction first, then taking over a group, joint operations on large targets) in the plan's "Ideas and maybe".
