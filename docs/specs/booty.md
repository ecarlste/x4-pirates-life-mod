# Spec: Booty v1

Plan item: Phase 2, slice 3, "Booty v1" · Status: Draft

## Goal

The player hands a prize to the Vigor Syndicate at their wharf or shipyard in Windfall I. They're paid twice: credits, like a sale minus the fence's cut, plus booty, the Vigor currency. Booty also raises their standing with Vigor, through many levels. Levels open bigger turn-ins, a lower cut, and tiers of pirate variants of ships and gear. The player buys a variant's unlock (or its blueprint) with booty in a conversation at a Vigor station, then buys the variant itself with credits in Vigor's normal build menus, or builds it at their own yard from the blueprint.

## Context

- Design: [DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing). Data, numbers and checks still to make: [research/booty.md](../research/booty.md).
- **Unlocks:** one hidden research ware per unlock, proven in game ([proof of concept](../research/booty.md#proof-of-concept-in-game-2026-10-27); code on branch `spike/unlock-research-poc`). The menu shows a locked variant in red with our research name under "Required research:" (`menu_ship_configuration.lua:7222`, `checkLicence`).
- **The pirated mark:** whether a prize counts as pirated or a donation comes from [pirated-ships.md](pirated-ships.md): ships taken by boarding or bailing in combat with the player's ships. Booty asks `md.APiratesLife_Pirated.IsPirated` at handover.
- **Vanilla's ship sale is Lua:** the map's sell-ships context prices each ship with `GetTotalValue(ship, true, shipyard)`, pays with `TransferMoneyToPlayer(price, shipyard, "sellship")` and removes it with `C.SellPlayerShip(ship, shipyard)` (`base/ui/addons/ego_detailmonitor/menu_map.lua:3852`, `:26256`). Our Lua (loaded by `ui.xml`) loads without UI Extensions, so MD can ask it to do the same through `raise_lua_event` and get the answer back through `AddUITriggeredEvent`, as the settings bridge does. Proven by the game tests (2026-10-27): the sale works on a ship docked at a Vigor wharf the player has never visited, 8 km away.
- **Station staff:** every NPC wharf and shipyard gets a ship trader at universe setup (`base/md/inituniverse.xml:619`). Hailing a station talks to its staff too. Both go through vanilla's `DefaultComm` (`base/md/conversations.xml`), where a non-player station NPC's choices use `top_left` (hiring, live stream), `bottom_left` (jobs), `top_right` (directions) and `bottom_right` (goodbye).
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
- **State per game:** `global.$APiratesLife_Groups.{'$' + id}` = `table[$standing, $booty, $unlocks]` (MD tables need string keys that start with `$`). Standing only goes up; booty goes up and down; `$unlocks` lists the unlocks bought.

### Handing a prize over

- **Two ways in:**
  - **The order:** "Hand over as booty", an order on a player-owned ship (`aiscripts/order.apirateslife.handover.xml`). It docks at the nearest group station that can take the ship, then asks for the handover.
  - **The station's staff:** hailing a group wharf or shipyard, or talking to its ship trader in person, offers "Hand over booty" (position `left`). It lists the player's ships docked there, four to a page with "More ships", pirated ones marked. Ships that can't be handed over show greyed out with the reason as a tooltip (too big for the level, the player aboard, already being handed over). Choosing one hands it over at once, with no confirmation step: the notification says what it paid.
- **Who qualifies:** a player-owned, operational ship that the player isn't flying, whose size the player's level accepts. Ships with the player or the player's ship docked on them don't qualify.
- **The handover:**
  1. *(Second PR.)* Move the pilot to a free marine slot (vanilla reassignment): on the nearest of the player's ships that has one, searching the whole fleet in every sector, nearest first (same sector by distance, then other sectors by jumps). Only when no ship anywhere has a free slot does the pilot go with the ship, as in a sale.
  2. The handover joins a queue (`global.$APiratesLife_Handovers`); the oldest goes to our Lua (`ui/apirateslife_booty.lua`) on the player blackboard (`$APiratesLife_BootyRequest`, which Lua reads without the `$` on its keys). One sale is with the Lua at a time, so its answer is always for that one. A request the Lua doesn't answer in 30 s of game time is dropped with an error line; a save loaded with requests waiting sends them again.
  3. The Lua prices the ship with `GetTotalValue(ship, true, station)`, pays price × (1 − the level's cut) with `TransferMoneyToPlayer`, removes the ship with `C.SellPlayerShip`, the same as a sale, and answers with the price.
  4. Booty: price × taste × (stolen bonus if pirated). Standing: booty × the standing gain setting. A level-up shows a notification.
  5. Rep with the station's owner goes up by `BootyRepPerMillion` (0.001 in the game's relation units) per million booty, unless the owner's relations are locked. A fighter (about 1.2M) gives about 0.0012; the military licence needs 0.01.
  6. One log line: `[apirateslife] booty: …` with the ship, price, credits, booty, standing and level, so a playtest can be checked against the metrics.
- **The price is the sale's price.** Whether `.value` counts hull damage and cargo stops mattering, because the engine's sale price is used for both payments. That check is still made in game ([to verify](../research/booty.md#to-verify-in-game)) for the metrics.

### Variants

- **The list:** `profiles/vanilla/variants.xml` in the repo (not shipped). Each entry names the vanilla ship or ware, the recipe and the level that offers it; an entry can be a rule (macro pattern, class, size). The recipes are stat multipliers by kind (e.g. a fighter: hull, speed, weapon slots unchanged; a weapon: damage, heat, range). The numbers go to Erik as a design proposal with the variants PR.
- **The generator:** `tools/generate_variants.py`, reading the list and the unpacked game files (`/mnt/e/x4-dev/reference/x4-9.00/`). It writes:
  - the variant macros (`assets/…`) and their `index/macros.xml` entries;
  - `libraries/wares.xml` additions: each variant owned by the group's factions, priced at the vanilla price × the price multiplier, with its research ware as a precursor;
  - one research ware per unlock (`tags="hidden research"`), and a separate one per blueprint unlock;
  - the names in `t/0001-l044.xml`: "Pirate" variants of the vanilla name, and research names that say what the unlock needs, e.g. "Vigor unlock: standing level 3, buy with booty".
- **Kept in sync:** `make test` runs the generator in check mode (on a small fixture of game files, so CI doesn't need the game), failing if the committed output differs from what the list makes.
- **The first set:** about one ship per size from Vigor's own range and a few S/M weapons and shields in Mk1–Mk3 tiers.

### Buying unlocks

- **In the conversation** with the manager of a group station: the player's booty, standing and level, then the unlocks at or below their level that aren't bought yet, each with its booty cost. Buying one takes the booty and grants the research (`add_research`); a blueprint unlock grants the blueprint too (`add_blueprints`).
- **Costs:** an unlock costs the variant's vanilla price × the unlock cost multiplier, in booty; a blueprint costs vanilla's blueprint price for it × the blueprint cost multiplier.
- **Nothing is taken back:** no `remove_research`, ever. Losing rep with Vigor only stops docking and trading at its stations.

### Settings

In `md/apirateslife_config.xml`, under Tuning, each added by the PR that first uses it. The first PR adds `BootyCutStart` (40), `BootyCutFloor` (10), `BootyStolenBonus` (1.5), `BootyStandingGain` (1.0) and `BootyRepPerMillion` (0.001); the variants and unlocks PRs add the variant price and the unlock and blueprint cost multipliers. The level thresholds stay in the profile. Which of them go on the settings page is decided by the page's [rule](in-game-settings.md#design).

## Tasks

- [x] Profile library, group state, the handover by conversation with the Lua sale, the booty settings
- [ ] The handover order, and the pilot's move to a marine slot
- [ ] Variant list, generator with its tests and sync check, the first set of variants
- [ ] Unlock conversation and blueprint unlocks

## Done when

The scenarios in [`tests/game/features/booty.feature`](../../tests/game/features/booty.feature) pass, and in Erik's game a captured ship handed over at the Vigor wharf pays credits and booty, and an unlocked variant can be bought there and built and delivered.

## Open questions

- **Rep per handover:** built as 0.001 relation per million booty, to tune in playtests. How that shows as reputation points depends on where the player stands (the game's scale isn't linear).
- **The recipes and the first set:** a design proposal with the variants PR.
- **In game, still to check:** at what relation Vigor stops docking and trading; whether Vigor's own ships start using our variants; the conversation at the real Windfall I stations (`@manual`). Answered: the Lua sale works on a ship away from the player (game tests).
