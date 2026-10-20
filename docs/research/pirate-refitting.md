# Refitting captured ships as a pirate

**Status: WIP.** The game files are mapped. Nothing here has been checked in game yet; the "To verify in game" list says what's still open. References are to X4 9.00 unpacked under `E:\x4-dev\reference\x4-9.00\` (`base/`, `ego_dlc_*/`). Player reports are linked where used and may describe older versions.

**The question:** captured S/M ships often arrive with empty weapon, turret and shield slots. Some ships spawn that way, and vanilla bail sabotage and marine-claim damage used to make it worse (the mod now stops both by default, see [claim-no-damage](../specs/claim-no-damage.md)). S/M equipment can't be shot off, so whatever a prize has when it bails is what it keeps. How does a pirate fill the empty slots?

**Scope (Erik):** players aren't limited to pirate suppliers, but a pure pirate must never *need* a legit faction to arm their ships. The routes below assume the worst case: a pirate hostile to everyone legit, who can still earn rep with pirate factions.

## Summary

- **Buying gear is gated by licences, and licences by relation.** General-use equipment needs relation above −10 UI (better than enemy). Military equipment (almost every real combat weapon) needs +10 and a promotion ceremony. Capital equipment needs +20. Every faction uses the same thresholds.
- **To fit S/M gear, a station needs an S/M build module.** Wharfs and equipment docks have one. Pirate bases, HAT free ports and the SCA anarchy port don't. The SCA pirate dock only has L/XL modules.
- **No pirate-tagged faction in the base game has a station that fits S/M gear.** The only ones in reach are Tides of Avarice's: the Vigor Syndicate wharf (pirate-tagged) and the Riptide Rakers wharf (salvagers, not tagged pirate). Both sell only general-use gear until you reach +10 with them.
- **Scale Plate Pact is a dead end for S/M refits.** Its relation is locked at −5, so you can dock and buy general-use gear, but it has no S/M fitting station and only owns a few mk1 basics. Military gear stays out of reach, since the only unlock is a terraforming milestone.
- **Your own wharf or equipment dock is the late route.** It needs equipment blueprints, plus the S/M build-module blueprint, which no pirate faction sells. Pirate routes to blueprints exist: hacking module data leaks, agent espionage (stealing equipment blueprints from any faction's equipment dock), pirate reps' blueprint sales, and blueprint crates.
- **Vanilla has no way to take equipment off one ship and keep it.** Removing gear at an NPC dock refunds credits. Lockboxes and ship drops never contain weapons or shields. Ventures don't add equipment either.
- **Raiding a faction can pay for its gear.** Every legit faction starts hated by several pirate factions (Terrans: Yaki, SCA, Fallen Families, then Buccaneers, Vigor, Riptide). Delivering booty taken from a faction to the pirates who hate it could unlock "pirated" versions of that faction's gear: same models, plus a vanilla-style bonus-and-drawback mod. See [Raid a faction, arm from its enemies](#raid-a-faction-arm-from-its-enemies).
- **The mod can fill this gap with existing MD actions:** `apply_loadout` can copy one ship's loadout onto another, `generate_loadout` can build a loadout from a list of allowed wares, and blueprint drops can be spawned. That makes stripping prizes, hideout refits, fence stock and hunter loot all buildable without engine work.

## How buying equipment works

### Licences and relation

Every weapon, turret and shield ware has a `<restriction licence="…"/>` (e.g. `base/libraries/wares.xml:15954`). Each faction defines the relation needed for each licence (`base/libraries/factions.xml:94–116` for one faction; all factions use the same values):

| Licence | Needs | UI value | Covers (S/M) |
| --- | --- | --- | --- |
| `generaluseequipment` | relation ≥ −0.01, granted automatically (`tags="basic"`) | better than −10 | pulse lasers, mining lasers, every standard shield, laser and mining turrets |
| `militaryequipment` | ≥ 0.01 plus the friend ceremony | +10 | ion, beam, plasma, blast, shard, gatling, shotgun, railgun, missile launchers, most M turrets |
| `capitalequipment` | ≥ 0.1 plus the ally ceremony | +20 | L/XL main guns and most L turrets |

The UI mapping is in the header of `factions.xml` (lines 3–25): 0.01 = 10, 0.0032 = 5, and −0.01 = −10 is where "enemy" starts.

Tallied across base and all DLC `wares.xml` files: of the base game's S/M weapons, only the pulse laser (`weapon_gen_s/m_laser_01`), mining lasers and the Xenon, Boron and Terran equivalents are general-use. Every other combat weapon is military. **Shields are all general-use** except the Kha'ak ones and a few Split/Boron mk2+/L variants. So a neutral pirate can always buy shields and pulse lasers wherever they can dock and fit. Everything else needs +10.

### Who sells what

A station sells equipment whose ware lists its owner faction (`<owner faction="…"/>`); the blueprint menu filters the same way, by licence owner (`base/ui/addons/ego_detailmonitor/menu_trader_blueprintsorlicences.lua:204-222`). Equipment owned by each pirate faction:

| Faction | Tagged pirate? | Owns (weapons / turrets / shields) | Notes |
| --- | --- | --- | --- |
| Scale Plate Pact (`scaleplate`) | yes (`factions.xml:540`) | 8 / 5 / 5 + 3 Envoy items | mk1 pulse laser and mining laser, Teladi mk1 shields and laser turrets, dumbfire and guided launchers (military) |
| Hatikvah's Choice (`hatikvah`) | yes (`factions.xml:298`) | 6 / 7 / 4 | the same kind of mk1 basics, Argon flavour |
| Duke's Buccaneers (`buccaneers`) | yes (`factions.xml:215`) | 40 / 34 / 20 | a full Paranid/Argon range, but see blockers |
| Vigor Syndicate (`loanshark`) | yes (`ego_dlc_pirate/libraries/factions.xml:123`) | Argon S/M/L/XL shields and turrets, the full `weapon_gen_*` set (beam, gatling, plasma, shotgun, launchers) | added as owner by the ToA `wares.xml` diff |
| Riptide Rakers (`scavenger`) | **no**: tags `claimspace economic extrarepair …` (`…/factions.xml:173`) | same as Vigor, plus scrap beam turret | salvage culture; Erik's call whether they count as pirates |
| Fallen Families, Yaki | yes | nothing / 1 mine | Yaki general-use needs +10 (`ego_dlc_terran/libraries/factions.xml:239`); start at −0.32 (UI −25) |

### Where gear can be fitted

Fitting needs a build module that can equip that ship class (`canequipships`, `canequipclass` in `base/libraries/scriptproperties.xml:675-681`). S/M ships need `buildmodule_*_equip_m_dockarea_01` (equipment docks) or `buildmodule_*_ships_m_dockarea_01` (wharfs).

| Station | Faction, sector | Build modules | Can fit S/M? |
| --- | --- | --- | --- |
| Pirate dock `gen_piratedock` | SCA, Hewa's Twin IV The Cove (`base/libraries/god.xml:1534`) | `buildmodule_gen_equip_l`, `_xl` (`base/libraries/constructionplans.xml:546`) | **no**: L/XL only |
| Pirate bases `gen_piratebase` | SCA, Grand Exchange III, Silent Witness XII (`god.xml:1549,1564`) | none (`constructionplans.xml:1055`) | no |
| Anarchy port | SCA, Loomanckstrat's Legacy (`god.xml:2527`) | none (`constructionplans.xml:6845`) | no |
| Free ports `gen_freeport` | HAT, Heretic's End, Second Contact VII, Silent Witness XI (`god.xml:838-868`) | none (`constructionplans.xml:1486`) | no |
| Hidden depot | BUC (`god.xml:2483`) | none | no |
| Vigor wharf, shipyard | Windfall I Union Summit (`ego_dlc_pirate/libraries/god.xml`, `loanshark_wharf_01`, `loanshark_shipyard_01`) | wharf: `ships_m_dockarea`; shipyard: `ships_l`, `_xl` (`ego_dlc_pirate/libraries/constructionplans.xml:710,881`) | **yes** (wharf) |
| Riptide wharf, shipyard | Avarice I (`scavenger_wharf_01`, `scavenger_shipyard_01`) | wharf: `ships_m_dockarea` (`…/constructionplans.xml:1113,1330`) | **yes** (wharf) |
| Yaki wharf | Savage Spur I (`ego_dlc_terran/libraries/god.xml`) | not traced | Yaki start at kill relation |

SCA, HAT and BUC equipment docks and wharfs exist only as station *types* (`base/libraries/stations.xml:15-61` lets Teladi or Argon docks belong to SCA or HAT), but `god.xml` never places one for them. Station placement is fixed in `god.xml`: there are no dynamic shipyard or equipment-dock products. A player report agrees that SCA "do not have their own dock or shipyard" ([Steam, 2021](https://steamcommunity.com/app/392160/discussions/0/3154186375141406119)).

### Relation blockers

- **SCA:** relations `locked="1"`, player at −0.0032 (UI −5) (`base/libraries/factions.xml:567,577`). You can dock (not enemy) and attacking them costs nothing. The only vanilla unlock is the Scale Plate Green terraforming milestone, which sets the player to friend (`base/md/terraforming.xml:2313-2321`), confirmed by [player reports](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Factions/Scale%20Plate%20Pact/). Terraforming is an HQ economy project, not piracy.
- **BUC:** locked at −0.032 (UI −15, enemy) (`factions.xml:248,259`) until stage 1 of the Paranid story's escalation (`base/md/story_paranid.xml:288-297`). No docking until then.
- **Vigor:** player starts at −0.0032 (UI −5), or +5 in the ToA "Smuggler's Paradise" start (`ego_dlc_pirate/libraries/gamestarts.xml:97`). Not locked, so rep moves both ways. Vigor is also tagged `police` (`…/factions.xml:123`): piracy in their space draws their police, and attacking their ships costs rep with your only S/M supplier.
- **Riptide:** player starts at 0 (no relation entry), or −5 in Smuggler's Paradise.
- **HAT:** starts at 0, but has no fitting station, so rep there only buys blueprints.
- **Legit factions:** hostility (UI −10 or worse) blocks docking and trade. The constraint above rules them out anyway.

### Refunds

At NPC stations, equipment removed in the ship configuration menu is refunded in credits (`shoppinglistrefund`, `menu_ship_configuration.lua:7977-7993`). At player-owned stations nothing is paid (`menu.isplayerowned`, `:1368`, `:1802`). Players report that stripping a captured ship's equipment before selling it pays much better than selling it whole ([Steam](https://steamcommunity.com/app/392160/discussions/0/4407417241457692100/)). That's vanilla's only "fence the equipment" path, and it pays in credits, not parts.

## Blueprints and your own docks

A player-owned wharf or equipment dock fits equipment for free (no price), using the station's build resources. It needs the **blueprint** of every ware in the loadout (`GetMissingLoadoutBlueprints`, `menu_ship_configuration.lua:3810`).

**The fitting module itself:** `module_gen_equip_dockarea_m_01` (equipment dock) and `module_gen_build_dockarea_m_01` (wharf) need the `station_equip_sm` licence (ally, +20) and are owned only by legit factions: Argon, Antigone, Paranid, Holy Order, Teladi, Trinity, Xenon, Split, Free Families (`base/libraries/wares.xml:4638-4667,5003-5024`; `ego_dlc_split/libraries/wares.xml`). **No pirate faction sells them.** Vigor and Riptide have the licence type (`…/factions.xml:137-138,186-187`) but own no module to sell under it.

Ways a pirate can get blueprints:

| Route | What it gives | Gates | Evidence |
| --- | --- | --- | --- |
| **Pirate faction rep** (SCA at a pirate base, HAT, Vigor, Riptide, Yaki) | blueprints of that faction's owned wares, licence-gated | general-use at better than −10, military at +10 | reps' HQs: `base/md/factionlogic.xml:107-166` (HAT, SCA prefer `piratebase`), `ego_dlc_pirate/md/factionlogic.xml:15-39`, `ego_dlc_terran/md/factionlogic.xml:59-64`; menu `npc_factionrepresentative.xml:271-298`. A 2019 report says "most weapon blueprints" were sold at the SCA base ([Steam](https://steamcommunity.com/app/392160/discussions/0/1635292137570601422/?l=japanese)); 9.00's SCA owner lists are much shorter |
| **Hacking module data leaks** (EMP, then scan every leak) | that module's blueprint, e.g. a legit equipment dock's S/M module | the module's research precursors done at the HQ | `base/md/signal_leaks.xml:1855-1882`; the module needs `research_module_build` (`wares.xml:5012-5016`); players report EMPs sold at the pirate base in Hewa's Twin IV ([Steam](https://steamcommunity.com/app/392160/discussions/0/4355617246779177812)) |
| **Agent: Steal equipment blueprint** | a random general-use, military or capital equipment blueprint from the target faction | HQ plus embassy research (`research_diplomacy_network`), an espionage agent with 20 experience, 125,000 Cr, 7 influence, 5 `inv_electronics`, 50% success, 30 min. Target: any faction's equipment dock | `base/libraries/diplomacy.xml:187-206`, `base/md/diplomacy.xml:2540-2556`, embassy unlock `base/md/diplomacy.xml:422-490` |
| **Agent: Steal module blueprint** | a module blueprint (S/M and L/XL equipment modules are in the high-value pool) | 100 experience, 350,000 Cr, 12 influence, high risk, targets a faction HQ | `base/libraries/diplomacy.xml:208-222`, `base/md/diplomacy.xml:2489-2499` |
| **Blueprint crates** | a fixed blueprint | find the crate | the Erlking vaults drop equipment-ware collectables (`ego_dlc_pirate/libraries/drops.xml:4-47`); collecting one is a "blueprint drop" (`event_player_collected_blueprint`, `base/libraries/common.xsd:15516`) |
| Research at HQ | modules and software, not weapons | — | Ship Reverse Engineering, which turns ships into blueprints, is a mod, not vanilla |

Stealing from legit factions is theft, not buying, so it fits Erik's constraint. Hacking and agents both need an HQ, which makes them mid-to-late career routes.

## Other vanilla routes checked

- **Lockboxes and ship drops:** inventory items, weapon mod parts and missiles only (`base/libraries/drops.xml:1100-1810`, `ship_small_pirate` at 1425). No weapons, turrets or shields.
- **Salvage and scrap (ToA):** tugs tow wrecks to scrap processors, which turn them into `rawscrap` and then `scrapmetal` (`base/libraries/wares.xml:9380,9905`; `ego_dlc_pirate/libraries/wares.xml`: `module_gen_proc_scrapworks`). Raw materials only, no equipment. NPC "recycle" orders (`base/aiscripts/order.build.recycle.xml`) are faction-internal.
- **Moving equipment between ships:** no player action does this. Ships can't carry equipment wares as cargo. MD can (see below).
- **Ventures:** I found no equipment rewards in the game files (`base/md/story_ventures.xml` grants nothing; rewards are server-side). Not a refit route to rely on.
- **Black-market and "shady" traders:** not traced in detail. From player reports, they deal in inventory items (EMPs, illegal goods), not equipment. Pirate bases trade wares through plain dock areas, with no build module to fit anything.

## Routes by career stage (pirate only)

| Stage | Realistic routes | What blocks the rest |
| --- | --- | --- |
| **1. Small-time raider** (S fighter, no HQ) | Vigor or Riptide wharf: shields and pulse lasers at neutral. Fly prizes as they are. Strip unwanted prizes at the wharf for credits | Military weapons need +10 Vigor. SCA can't fit S/M ships. HAT and SCA bases can't fit anything. BUC is enemy-locked. Windfall and Avarice are one corner of the map, a long flight from most hunting grounds |
| **2. Raider captain** (M ships + wing) | Grind Vigor to +10 (missions, killing their enemies) to unlock military gear. Mix and match prizes: keep the armed ones, strip the rest | Vigor police make Windfall a bad place to hunt. Rep loss from piracy against Vigor ships |
| **3. Corsair** (L ships + hideout) | SCA pirate dock refits L/XL (general-use only). Vigor/Riptide shipyards for L/XL. HQ unlocks hacking and agents. Your own equipment dock once you've hacked or stolen the S/M module | Military and capital gear need +10/+20 with Vigor or Riptide, or stolen blueprints. The station still needs build resources (a supply chain or purchases) |
| **4. Pirate lord** | Your own docks with stolen blueprints; Vigor/Riptide at +20 | Blueprint coverage is random (agents roll from pools) |

**The gap:** stages 1–2 have one supplier corner (Windfall/Avarice) and only general-use gear. Players without Tides of Avarice would have *no* pirate S/M refit at all, but the mod requires it. The design's "no soft-locks: a pirate-friendly fence and repair option always exist" ([DESIGN.md, Difficulty and economy model](../DESIGN.md#difficulty-and-economy-model)) currently holds only for repair at Vigor/Riptide, not for fitting military gear.

## Raid a faction, arm from its enemies

Erik's idea (2026-10-20): a player who keeps raiding one faction, say the Terrans, hands the "booty" to a pirate faction that hates the Terrans. That builds rep with them, and eventually they sell *pirated Terran gear*: the same models as Terran gear, but "pirate modified", with bonuses and drawbacks compared to the legit Terran sellers. It's only offered to players who are low enough with the Terrans **and** have delivered enough Terran booty. The general form: every faction you prey on has enemies who'll arm you with its own gear.

### Who hates whom at game start

Start relations (UI values) between pirate factions and the factions they could fence for, from all `factions.xml` files (each faction's `<relations>` plus the DLC diffs). Diplomacy changes these during play, so the mod must query them at runtime and never store this table.

| Pirate faction | Argon | Antigone | Paranid | Holy Order | Teladi | Ministry | Split | Free Families | Terran | Pioneers | Boron |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Scale Plate Pact | −25 | −20 | −25 | −25 | 0 | −25 | −25 | −20 | −25 | −25 | −25 |
| Hatikvah's Choice | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Buccaneers | −15 | −15 | −15 | −15 | 0 | −15 | −15 | −15 | −15 | −15 | −15 |
| Vigor Syndicate | −15 | −15 | −15 | −15 | 0 | −20 | −15 | −15 | −10 | −15 | −15 |
| Riptide Rakers | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | −10 | 0 | +15 |
| Fallen Families | −25 | −20 | −25 | −25 | −20 | −25 | −25 | +20 | −25 | −25 | −25 |
| Yaki | −25 | −25 | −25 | −25 | −25 | −25 | −25 | −25 | **−30** | −10 | −25 |

- **Every legit faction except Teladi has at least two pirate factions at −15 or worse.** Teladi is only hated by the Fallen Families and Yaki, and it's SCA's parent race.
- **Terran → Yaki is the natural pair.** The Yaki are Terran-descended pirates, start at nemesis (−30) with the Terrans, and own a wharf in Savage Spur I. But they start at −25 with the player and need +10 even for general-use gear (`ego_dlc_terran/libraries/factions.xml:233-241`), so raiding Terrans is how you'd win them over.
- **HAT hates nobody**, so it would never be a supplier for this; it fits better as a neutral fence.
- Vanilla factions already "like" specific wares as diplomatic bribes (`base/md/diplomacy.xml:95-100`; Vigor and Riptide added in `ego_dlc_pirate/md/setup_dlc_pirate.xml:47-49`). Booty-for-rep is a pirate twist on that.

### How it could be built

- **Finding suppliers, profile-free.** For a target faction T: the factions tagged `pirate` (`.hastag`, the tag in `factions.xml`), or a profile's list of fences, whose relation to T is in the enemy range or worse (`get_factions_by_relation`, `relationto`; `base/libraries/common.xsd:20161`). Runtime queries follow wars and peace deals made by vanilla diplomacy.
- **The booty ledger.** Our MD keeps a per-(supplier, target) tally of booty delivered. Vanilla wares carry no record of where they came from, so we tag at capture time: our `Bailed` signal and claims already know the target's owner, so a captured ship and its cargo count as T booty. "Delivering" means selling or handing it in at a supplier's station (a conversation option, or tracking sales there). Each delivery raises rep with the supplier through `add_faction_relation` (`common.xsd:20134`), scaled like the design's other payouts.
- **The gate.** Offer pirated T gear when the player's relation to T is at or below a threshold **and** the ledger for (supplier, T) passes a threshold. Both are sliders. Recovering rep with T closes the shop again, which nudges the player to keep raiding.
- **What's for sale.** The items unlocked by reverse engineering (below). Without that step, the fallback is T's equipment queried by owner: `get_ware_definition` with `faction` and `<owner … licencefaction>` filters (vanilla does this in `base/md/diplomacy.xml:2543-2556`), split by `tag.weapon`, `turret`, `shield`. No ware IDs in our scripts.
- **"Pirate modified": two options.**
  - **A. Vanilla gear plus a pirate mod (recommended first).** Fit T's real ware, then apply an equipment mod with `add_equipment_mods` (vanilla does this in `base/md/rml_board_ship.xml:152-160`). Vanilla mods already pair a bonus with a drawback, e.g. `mod_weapon_damage_02_mk1`: damage ×1.35–1.45, cooling ×0.68–0.74 (`base/libraries/equipmentmods.xml:23-27`). We'd add our own "pirate rig" mods through an `equipmentmods.xml` and `wares.xml` diff. No new models, macros or stats files.
  - **B. New equipment macros.** A new macro that reuses the vanilla component (same model) with its own stats, plus a new ware. Truly separate items in the encyclopedia and the shop, but much more data per ware, and it has to be generated for every universe (SWI included).
- **Selling it.** Station stock is driven by static `<owner>` lists and licences, so it can't be gated per player. Licence types are a fixed list (`licencelookup` enum, `base/libraries/common.xsd:4402-4440`), so a custom "pirated gear" licence is unlikely to work. The shop has to be ours: a fence or pirate-contact refit service that fits gear with `apply_loadout` and then applies the pirate mod. This is the same service as design ideas 2 and 4, so it's built once.

### Unlock by reverse engineering booty

Erik's refinement (2026-10-20): unlocks go per gun, not per faction or ship size. Every ship turned in as booty counts the weapons, turrets and shields it carries. Turn in, say, 10 ships that carry a given gun, and the pirate vendor has reverse engineered it: its pirated version is now for sale. (This replaces an earlier draft that unlocked gear by ship size.)

- **How it's counted.** When a ship is turned in, MD lists its fitted equipment (`$ship.weapons.operational.list`, likewise `.turrets` and `.shields`; `base/libraries/scriptproperties.xml:531-548`) and maps each item to its ware (`.macro.ware`, `scriptproperties.xml:2070` onward). The ledger is per (supplier, ware): +1 for each turned-in ship that carries that ware, not per copy, so one gunboat doesn't unlock a gun on its own. Vanilla does the same kind of loop in `base/md/scenario_combat.xml:1210`.
- **Sizes take care of themselves.** S/M ships carry S/M guns and L ships carry L turrets, so the size problem from the earlier draft disappears. The career stages still pace it, since big guns come from big prizes.
- **The rest of the design stays.** The supplier must hate the faction that owned the turned-in ship, and the player must still be low enough with that faction for the vendor to deal. The booty also raises rep with the supplier.
- **Why it's good:**
  - It's legible: "7/10 Terran beam emitters collected" is an easy progress bar.
  - It's player-directed: you hunt ships that carry the gun you want, which gives target selection a reason beyond cargo value.
  - It ties into intact captures: a gun destroyed by bail sabotage can't be counted, which gives the `IntactOnEject` / `IntactOnClaim` settings a gameplay cost.
  - It needs no hardcoded IDs and no size data; whatever a universe's ships carry is what can be unlocked.
- **Choices to make:**
  - The threshold (10 is Erik's example): one global setting, or scaled by tier or rarity (fewer for L/XL guns, which come from rarer prizes).
  - Does the ledger stay with the supplier, or does any pirate faction that hates the owner accept the "blueprint"?
  - Do mk1/mk2 count separately? They're separate wares, so by default yes.
  - What about gear the vendor could already sell in vanilla (e.g. general-use pulse lasers): skip it, or still offer a pirated version?
- **Vanilla precedent:** none for reverse engineering in the base game; Ship Reverse Engineering is a mod. The closest vanilla mechanic is research-gated blueprints from data leaks.

### Open questions

- Do pirate mods stack with, or replace, vanilla mods the player applies later at a mod workbench?
- Should pirated gear be *better* overall (a reward for commitment), or only different (more damage, more heat, less durability)?
- Should a supplier's own wars count? Riptide likes Boron and dislikes Terrans; Fallen Families like the Free Families.
- What exactly counts as booty: captured ships, cargo from drops, ransoms, destroyed T ships?

## Building blocks the mod can use

- **`apply_loadout object="$ship" loadout="$other.loadout"`** copies a whole loadout onto an existing ship. Vanilla does this in `base/md/gm_barterwares.xml:2263`. `flags` can limit it to `weapons shields turrets` and `add`/`remove` (`base/libraries/common.xsd:4887-4997`, `24586`).
- **`generate_loadout macro="…" wares="$allowed" level="…"`** builds a loadout from a list of allowed wares (`common.xsd:24316`; vanilla passes `wares` in `base/md/finalisestations.xml:126`). Feeding it the wares in our stash would give a "refit from what you've salvaged" loadout.
- **`.weapons`, `.turrets`, `.shields` with `.numslots`, `.<state>.count` and `.<state>.list`**, plus `.loadout` (`base/libraries/scriptproperties.xml:468,531-547`), let us find empty slots and list the fitted equipment. Vanilla sabotage already destroys equipment (the bail and claim cues we patch), so removing it from MD works.
- **Blueprint drops:** a droplist with an equipment ware in `<collectable><wares>` (`ego_dlc_pirate/libraries/drops.xml:4-47`) gives the blueprint when collected, and fires `event_player_collected_blueprint`.
- **`add_blueprints wares="…"`** grants blueprints directly (`base/md/playerreputation.xml:350`, `base/md/diplomacy.xml:5040`).
- **Ware owners and licences** are library data: a `wares.xml` diff can add `<owner faction="…"/>` for a pirate faction, which is how ToA added Vigor and Riptide. Faction IDs in such a diff are universe data, so they belong in the vanilla profile, not the core.

## Design ideas

Ordered by how well they fit the design and how cheap they look. None are agreed yet.

1. **Strip prizes for parts ("salvage stash").** At the hideout, or at a pirate dock where we offer the service, the player strips a captured ship. Its weapons, turrets and shields go into a stash of parts per ware, kept as mod MD data (no engine inventory). Built with MD: read the ship's equipment, then remove it and add to the stash. The UI is a conversation menu or a kuertee UI hook. This turns every bad prize into parts and links "Cash in" with "Spend it".
2. **Refit from the stash.** Fill a ship's empty slots from the stash: `generate_loadout` restricted to stash wares, then `apply_loadout` with `add`, then deduct from the stash. Takes time and a fee. Done at the hideout first (stage 3), and at a pirate contact before that so stages 1–2 aren't blocked.
3. **Prize-to-prize transfer.** A shortcut for idea 1+2: "move this prize's weapons to that ship" (`apply_loadout` from one ship's loadout, then strip the source). Only for compatible slot sizes. Cheap to build first, and it covers the most common case right away.
4. **Fences sell stolen and salvaged gear.** Fences (slice 3) buy stash parts at a hot-goods cut, and sell a rotating stock of gear, military included, at a markup that scales with notoriety rather than licence rep. This answers "military gear without +10 anywhere" in a pirate way. Stock comes from the profile's equipment lists (queried by tag/licence, no hardcoded IDs).
5. **Bounty hunter loot.** Destroyed hunters drop a blueprint crate (blueprint-drop mechanic) or stash parts of their upgraded gear; a captured hunter keeps its high-end loadout. Fits [DESIGN.md, Bounty hunters](../DESIGN.md#bounty-hunters) ("loot from destroyed hunters").
6. **Pirate-faction reach via the profile.** The vanilla profile lists which factions count as pirates for supply (SCA, HAT, Vigor, maybe Riptide, BUC once unlocked) and can diff-patch extra `<owner>` entries or an S/M build module onto a pirate station (e.g. SCA's Cove dock). This needs a careful look at what other mods (and SWI) also patch.
7. **Raid a faction, arm from its enemies.** Booty taken from a faction buys rep with the pirates who hate it, unlocking pirated versions of its gear once enough turned-in ships carried each item ("reverse engineering"). See [Raid a faction, arm from its enemies](#raid-a-faction-arm-from-its-enemies).
8. **Data-leak and espionage hooks.** Lean on the vanilla theft routes: a fence or contact sells EMPs and leak locations, and notoriety unlocks agent targets. Mostly flavour on top of what exists.

**Fear vs. honor:** stripping a surrendered crew's ship bare could count as fear; letting them keep it could count as honor. A small hook for later.

## To verify in game

- Does a neutral (−5) player get offered general-use gear at the Vigor wharf, and do military items show as locked?
- Does the SCA Cove pirate dock really refit L ships for the player, and with what stock?
- Removing equipment at your own wharf or equipment dock: is anything returned to storage, or is it lost?
- Does `apply_loadout` with `flags="weapons shields turrets add"` fill only empty slots, or replace existing gear? Does it need the wares or blueprints?
- Collecting an equipment-ware collectable outside the Erlking story: does it really grant the blueprint?
- Where do BUC's shipyards come from in 9.00 (story or expansion)? `god.xml` places none.

## Sources

Game files as cited. Player reports:

- [Steam: SCA have no dock or shipyard, buy under false IDs (2021)](https://steamcommunity.com/app/392160/discussions/0/3154186375141406119)
- [Steam: blueprints at pirate bases (2019)](https://steamcommunity.com/app/392160/discussions/0/1635292137570601422/?l=japanese)
- [Steam: SCA locked at −5, docking permitted; EMPs at Hewa's Twin IV](https://steamcommunity.com/app/392160/discussions/0/4355617246779177812)
- [Steam: strip equipment before selling a ship](https://steamcommunity.com/app/392160/discussions/0/4407417241457692100/)
- [Egosoft wiki: Scale Plate Pact](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Factions/Scale%20Plate%20Pact/)
- [Egosoft wiki: Riptide Rakers](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Factions/Riptide%20Rakers/)
- [Nexus: Ship Equipment Salvaging (a mod with an EVA salvage inventory; page not readable, prior art to study)](https://www.nexusmods.com/x4foundations/mods/2227)
