# Spec: Booty v1

Plan item: Phase 2, slice 3, "Booty v1" · Status: Draft

## Goal

The player hands a prize to the Vigor Syndicate at their wharf or shipyard in Windfall I. They're paid twice: credits, like a sale minus the fence's cut, plus booty, the Vigor currency. Booty also raises their standing with Vigor, through many levels. Levels open bigger turn-ins, a lower cut, and tiers of pirate variants of ships and gear. Reaching a level unlocks its variants: the player buys them with credits in Vigor's normal build menus. Booty buys a variant's blueprint, in a conversation at a Vigor station, to build it at their own yard.

## Context

- Design: [DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing). Data, numbers and checks still to make: [research/booty.md](../research/booty.md).
- **Unlocks:** one hidden research ware per unlock, proven in game ([proof of concept](../research/booty.md#proof-of-concept-in-game-2026-10-27); code on branch `spike/unlock-research-poc`). The menu shows a locked variant in red with our research name under "Required research:" (`menu_ship_configuration.lua:7222`, `checkLicence`).
- **The pirated mark:** whether a prize counts as pirated or a donation comes from [pirated-ships.md](pirated-ships.md): ships taken by boarding or bailing in combat with the player's ships. Booty asks `md.APiratesLife_Pirated.IsPirated` at handover.
- **Vanilla's ship sale is Lua:** the map's sell-ships context prices each ship with `GetTotalValue(ship, true, shipyard)`, pays with `TransferMoneyToPlayer(price, shipyard, "sellship")` and removes it with `C.SellPlayerShip(ship, shipyard)` (`base/ui/addons/ego_detailmonitor/menu_map.lua:3852`, `:26256`). Our Lua (loaded by `ui.xml`) loads without UI Extensions, so MD can ask it to do the same through `raise_lua_event` and get the answer back through `AddUITriggeredEvent`, as the settings bridge does. Proven by the game tests (2026-10-27): the sale works on a ship docked at a Vigor wharf the player has never visited, 8 km away.
- **Station staff:** every NPC wharf and shipyard gets a ship trader at universe setup (`base/md/inituniverse.xml:619`), whose conversation is its own (`base/md/npc_shiptrader.xml`). Other station NPCs, the manager among them, go through vanilla's `DefaultComm` (`base/md/conversations.xml`), where a non-player station NPC's choices use `top_left` (hiring, live stream), `bottom_left` (jobs), `top_right` (directions) and `bottom_right` (goodbye). Erik couldn't hail the Vigor wharf from his ship (2026-10-27); talking to its manager in person works. The first version patched `DefaultComm` only, so the ship trader never offered it.
- **Moving the pilot to a marine slot:** vanilla's "work somewhere else" reassignment (`base/md/conversations.xml:1300-1330`).
- **Capture metrics** (`md/apirateslife_metrics.xml`) give the capture times behind the level thresholds.

## Design

Built in four PRs, each with its game tests, after the pirated mark:
1. **Groups and the handover by conversation**, with the Lua sale and the booty settings in the config file.
2. **The handover order and the pilot's move to a marine slot.** Moving the pilot is vanilla's actor reassignment (an NPC in transit, its state machine), big enough for its own PR.
3. **Variants.**
4. **Unlocks.**

### Groups and standing (data and state)

- **The vanilla profile:** `md/apirateslife_profile_vanilla.xml`, a library returning the groups. It's the only place for vanilla IDs: core scripts read groups, never factions by name. One group in v1:
  - **Vigor:** factions `[faction.loanshark]`; tastes by maker race (default 1, ×1.5 for `xenon`); ×0.75 for its own ships. Vigor's own ships have Argon as their maker race (there's no pirate race), so the profile lists their 8 macros instead (the ships whose wares Vigor owns in `ego_dlc_pirate/libraries/wares.xml`). A ship with several makers takes the highest taste.
- **Levels:** a list of `table[$standing, $size]`, the standing needed for each level and the largest ship size it takes (1 S to 4 XL). 21 levels from the [time targets](../research/booty.md#levels-and-thresholds): M at level 4 (6M standing), L at 8 (20M), XL at 15 (110M), the top at 20 (320M). Each unlock names its own level, so "tiers of unlocks" is unlock data, not level data.
- **The fence cut** isn't level data: it falls evenly from `BootyCutStart` (40%) at level 0 to `BootyCutFloor` (10%) at the top level, so the two settings tune it.
- **Stations:** found when needed, not listed: stations whose true owner is in the group's factions, `iswharf` or `isshipyard`, and that can dock the prize's size. Stations can be destroyed or change hands.
- **State per game:** `global.$APiratesLife_Groups.{'$' + id}` = `table[$standing, $booty, $blueprints]` (MD tables need string keys that start with `$`). Standing only goes up; booty goes up and down; `$blueprints` lists the blueprints bought.

### Handing a prize over

- **Two ways in:**
  - **The order:** "Hand over as booty", an order on a player-owned ship (`aiscripts/order.apirateslife.handover.xml`), with an optional station. With none chosen it goes to the nearest group station the player knows that can take the ship's size, by gates then distance.
    - AI scripts can't call MD, so the order signals the galaxy (`'apirateslife_handover_ask'`) and MD answers on the order's pilot (`$APiratesLife_HandoverStation`; ships can't hold variables). A ship that can't be handed over there (too big for the level, say) is refused before it flies, with a notification saying why.
    - It docks as vanilla's Dock and Wait does: a `DockAt` order in front of itself, then it starts again, finds itself docked and signals `'apirateslife_handover_docked'` for MD to hand it over. It gives up after three docking tries.
    - Vanilla undocks a docked ship before starting any order not on its list of orders that may run docked (`aiscripts/orders.base.xml`, around line 158; `TransferWorkers` is exempt because it undocks itself). Our order is exempted the same way by a one-line patch, or the ship would undock the moment its `DockAt` had docked it.
    - Found building the game tests (2026-10-27): **a station spawned at runtime with `create_station` only lets its own faction dock.** `dockingallowed` stayed false there for the player's ships and for a friendly Teladi ship, whatever the relation (up to +20), docking software, manager, ship trader or faction state, and `DockAt` logged "docking request denied". A map-placed station lets the player's ships dock, and still does after `set_owner` to Vigor at −5. So the game tests use the map-placed wharf of the docking tutorial's galaxy, given to Vigor. Real Vigor stations are map-placed, so players aren't affected; a later feature that spawns stations for groups would be.
  - **The station's staff:** talking to the manager or the ship trader of a group wharf or shipyard offers "Hand over booty": in person, or by comm from the map's crew list for that station once 60% of its information is unlocked (vanilla's `operator_name`; [research](../research/booty.md#to-verify-in-game)). The station itself can't be hailed. Our own cue adds it on `event_conversation_started` (and on returning to the main choices), for the station's `tradenpc` or `shiptrader`, the way Mysterial's Ship Reverse Engineering mod adds "Analyze ship". No vanilla conversation is patched, though the two NPCs use different scripts (`DefaultComm` in `md/conversations.xml`, and `md/npc_shiptrader.xml`), and no position is given, so the game picks a free slot.
  - **The list:** the player's ships docked there, found with `find_object_component … docked="true"` as the ship trader's "Upgrade a ship" finds them (`.docked` is a docking bay's property, not a station's). Four to a page with "More ships", pirated ones marked. Ships that can't be handed over show greyed out with the reason as a tooltip (too big for the level, the player aboard, already being handed over).
  - **Confirm:** choosing a ship asks "Hand over <ship> for good", as a handover can't be undone; back returns to the list. The price isn't shown before: only the Lua sale knows it. The notification says what it paid.
- **Who qualifies:** a player-owned, operational ship that the player isn't flying, whose size the player's level accepts. Ships with the player or the player's ship docked on them don't qualify.
- **The handover:**
  1. Move the pilot to a free marine slot, as vanilla's "work somewhere else" reassigns an instanced NPC (`md/conversations.xml`, around line 1240: off their post, the marine role on the new ship, an NPC template there, then their state machine moves them). A free slot is room for one more crew (`people.capacity` over `people.count`). The new ship is the nearest of the player's ships that has one, searching the whole fleet in every sector: same sector by distance first, then other sectors by gates. Only when no ship anywhere has room, or the prize has no NPC pilot, does the pilot go with the ship, as in a sale. In the game tests the pilot is still on the new ship after the prize is sold.
  2. The handover joins a queue (`global.$APiratesLife_Handovers`); the oldest goes to our Lua (`ui/apirateslife_booty.lua`) on the player blackboard (`$APiratesLife_BootyRequest`, which Lua reads without the `$` on its keys). One sale is with the Lua at a time, so its answer is always for that one. A request the Lua doesn't answer in 30 s of game time is dropped with an error line; a save loaded with requests waiting sends them again.
  3. The Lua prices the ship with `GetTotalValue(ship, true, station)`, pays price × (1 − the level's cut) with `TransferMoneyToPlayer`, removes the ship with `C.SellPlayerShip`, the same as a sale, and answers with the price.
  4. Booty: price × taste × (stolen bonus if pirated). Standing: booty × the standing gain setting. A level-up shows a notification.
  5. Rep with the station's owner goes up by `BootyRepPerMillion` (0.001 in the game's relation units) per million booty, unless the owner's relations are locked. A fighter (about 1.2M) gives about 0.0012; the military licence needs 0.01.
  6. One log line: `[apirateslife] booty: …` with the ship, price, credits, booty, standing and level, so a playtest can be checked against the metrics.
- **The price is the sale's price.** Whether `.value` counts hull damage and cargo stops mattering, because the engine's sale price is used for both payments. That check is still made in game ([to verify](../research/booty.md#to-verify-in-game)) for the metrics.

### Variants

- **The list:** `profiles/vanilla/variants.xml` in the repo (not shipped): the group (its id, the factions that own the variants, its name for texts), the rigs (multipliers on drag, travel acceleration, hull, crew and cargo), and one `<ship>` per variant (an id, the vanilla macro, its rig and the standing level whose unlock offers it). Rules that match many macros at once can come later. `<equipment>` entries do the same for an engine, shield generator, weapon or missile, with an optional fun `name`. A mark the base game stops short of (M and L shields Mk3, XL shields Mk2) takes `mark` and `step`: built from the base game's top mark, with the step rig (about vanilla's one-mark step, its `price` multiplying the ware's) applied once per mark up, on top of the rig, and named as that mark.
- **The generator:** `tools/generate_variants.py` (`make variants`), reading the list and the unpacked game files (`/mnt/e/x4-dev/reference/x4-9.00/`, or `$X4_REFERENCE`). For each ship it writes:
  - `assets/units/size_*/macros/ship_apl_<id>_macro.xml`: a copy of the vanilla macro on the same model, with the rig applied and our name; and `assets/props/storagemodules/macros/storage_apl_<id>_macro.xml`, a copy of its storage macro, when the rig changes cargo;
  - their entries in `index/macros.xml` (a plain `<index>`, as the DLCs ship it);
  - in `libraries/wares.xml`: the variant's ware `ship_apl_<id>` (a copy of the vanilla ship's, at its price × 1.25, owned by the group's factions, every production method needing the unlock research), and the unlock research `research_apl_<id>` (`tags="hidden research"`). A blueprint unlock needs no research of its own: it grants the variant's blueprint (`add_blueprints`), and the player already has the research;
  - in `t/0001-l044.xml`, page 1774110 between generated markers: "Pirate" and the vanilla name (its base name, without the variation), and the research's name and description, which say what the unlock needs ("Vigor Syndicate unlock: standing level 2").
- **Gear:** the generator copies an engine, shield generator, weapon or missile macro into its vanilla folder (lowercased) and rigs it:
  - **engines:** combat, reverse, travel and boost thrust, boost duration, and the boost recharge *rate* (the UI's "Boost Recharge Rate"; below 1 is slower);
  - **shields:** capacity, recharge rate and delay;
  - **weapons and turrets:** a copy of the weapon's bullet macro (`assets/fx/weaponfx/macros/bullet_apl_<id>_macro.xml`) with hull damage (`value`) and shield damage rigged;
  - **destructible twins:** gear whose macro has an `alias` (M turrets and shields: the twin is a ware of its own, the one the hittable slots of L and XL hulls take) gets a copy of that too (`<prefix>_apl_<id>_alias_macro`), rigged the same, and its ware (`<prefix>_apl_<id>_alias`), with the same name and unlock;
  - **missiles:** a copy of the missile's effect list (`libraries/influenceconfigurations.xml`, `apl_<id>`, a diff patch) with every duration rigged.
  Names: the vanilla gear name is "{maker} {size} {base name} {Mk}"; the maker becomes "Pirate" ("Pirate S Combat Engine Mk1"), or, with a fun name, the maker goes and the fun name replaces the base name ("S Stripper Mk1", "M Stripper Turret Mk1", "Cold Feet Mk1"). Ware IDs follow the macro: `engine_apl_combat_s`, `weapon_apl_stripper_s`, `missile_apl_coldfeet`.
- **Kept in sync:** `profiles/vanilla/variants.manifest` holds a stamp (a hash of the list and the generator) and a hash of every generated file; the files themselves carry no stamp, so a run changes only the files whose content changed, and the manifest. `make test` runs `generate_variants.py --check`: with the game files, it regenerates in memory and compares, then checks the manifest too; without them (as in CI), it checks the manifest: its stamp matches the list and generator, and every file it lists is there and unchanged, with none missing or left over. Unit tests run the generator on a small made-up install written in the test (`tests/python/test_generate_variants.py`), so no game data is committed. Python unit tests count as test-plan coverage, as the Lua ones do.
- **The first set:** as [DESIGN.md](../DESIGN.md#booty-and-pirate-standing) lists it (hulls by pirate role, base game and Tides of Avarice only; pirate engines, shields, the Stripper and the Stripper turret). The rig recipes are still being worked out in [research/pirate-variants.md](../research/pirate-variants.md#pirate-rigs-the-recipes).

### Unlocks and blueprints

- **Unlocks come with the level** (Erik, 2026-10-28): when standing reaches a variant's level, the player is granted its research (`add_research`), with no booty taken, and told what the level unlocked. On loading a game, every variant at or below the player's level is granted too, so a variant added to the list later, or a save from before, catches up. The generator writes each variant's group, level, research and ware into `md/apirateslife_variants_vanilla.xml` (library `Unlocks`), which the booty script reads. The player is told by a notification and a logbook entry naming what the group now sells them.
- **Blueprints are bought in the conversation** with the manager or ship trader of a group station: the player's booty, standing and level, then the blueprints of unlocked variants not bought yet, each with its booty cost. Buying one takes the booty and grants the blueprint (`add_blueprints`).
- **Blueprint cost:** vanilla's blueprint price for the variant × `BootyBlueprintCost` (high; the default to set when building it), and at least `BootyBlueprintFloor` (250,000) booty, so cheap items, missiles above all, aren't trivially cheap.
- **Nothing is taken back:** no `remove_research`, ever. Losing rep with Vigor only stops docking and trading at its stations.

### Settings

In `md/apirateslife_config.xml`, under Tuning, each added by the PR that first uses it. The first PR adds `BootyCutStart` (40), `BootyCutFloor` (10), `BootyStolenBonus` (1.5), `BootyStandingGain` (1.0) and `BootyRepPerMillion` (0.001); the variants and blueprints PRs add the variant price, `BootyBlueprintCost` and `BootyBlueprintFloor`. The level thresholds stay in the profile. Which of them go on the settings page is decided by the page's [rule](in-game-settings.md#design).

## Tasks

- [x] Profile library, group state, the handover by conversation with the Lua sale, the booty settings
- [x] The handover order, and the pilot's move to a marine slot
- [x] Variant list, generator with its tests and sync check, the first set of ships
- [x] The first set's gear: pirate engines, shields, the Stripper, the pirate EMP missile
- [x] The Stripper turret
- [ ] Unlocks granted with the level
- [ ] Blueprints bought with booty

## Done when

The scenarios in [`tests/game/features/booty.feature`](../../tests/game/features/booty.feature) pass, and in Erik's game a captured ship handed over at the Vigor wharf pays credits and booty, and a variant unlocked by reaching its level can be bought there and built and delivered.

## Open questions

- **Rep per handover:** built as 0.001 relation per million booty, to tune in playtests. How that shows as reputation points depends on where the player stands (the game's scale isn't linear).
- **The rig recipes:** still iterating (Erik, 2026-10-27): keep cargo valuable on some builds, for cargo turn-ins later. The first set is agreed.
- **In game, still to check:** at what relation Vigor stops docking and trading; whether Vigor's own ships start using our variants; the conversation at the real Windfall I stations (`@manual`). Answered: the Lua sale works on a ship away from the player (game tests).
