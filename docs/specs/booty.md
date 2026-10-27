# Spec: Booty v1

Plan item: Phase 2, slice 3, "Booty v1" · Status: Draft

## Goal

The player hands a prize to the Vigor Syndicate at their wharf or shipyard in Windfall I. They're paid twice: credits, like a sale minus the fence's cut, plus booty, the Vigor currency. Booty also raises their standing with Vigor, through many levels. Levels open bigger turn-ins, a lower cut, and tiers of pirate variants of ships and gear. The player buys a variant's unlock (or its blueprint) with booty in a conversation at a Vigor station, then buys the variant itself with credits in Vigor's normal build menus, or builds it at their own yard from the blueprint.

## Context

- Design: [DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing). Data, numbers and checks still to make: [research/booty.md](../research/booty.md).
- **Unlocks:** one hidden research ware per unlock, proven in game ([proof of concept](../research/booty.md#proof-of-concept-in-game-2026-10-27); code on branch `spike/unlock-research-poc`). The menu shows a locked variant in red with our research name under "Required research:" (`menu_ship_configuration.lua:7222`, `checkLicence`).
- **The pirated mark:** whether a prize counts as pirated or a donation comes from its own plan item, built first: ships taken by boarding or bailing in combat with the player's ships.
- **Vanilla's ship sale is Lua:** the map's sell-ships context prices each ship with `GetTotalValue(ship, true, shipyard)`, pays with `TransferMoneyToPlayer(price, shipyard, "sellship")` and removes it with `C.SellPlayerShip(ship, shipyard)` (`base/ui/addons/ego_detailmonitor/menu_map.lua:3852`, `:26256`). Our Lua (`ui/apirateslife_options.lua`, loaded by `ui.xml`) loads without UI Extensions, so MD can ask it to do the same through `raise_lua_event` and get the answer back through `AddUITriggeredEvent`, as the settings bridge does.
- **Moving the pilot to a marine slot:** vanilla's "work somewhere else" reassignment (`base/md/conversations.xml:1300-1330`).
- **Capture metrics** (`md/apirateslife_metrics.xml`) give the capture times behind the level thresholds.

## Design

Built in four PRs, each with its game tests: **groups and handover**, **variants**, **unlocks**, then the **settings**. The pirated mark comes before all of them.

### Groups and standing (data and state)

- **The vanilla profile:** `md/apirateslife_profile_vanilla.xml`, a library returning the groups. It's the only place for vanilla IDs: core scripts read groups, never factions by name. One group in v1:
  - **Vigor:** factions `[faction.loanshark]`; tastes by maker race (`argon`, `xenon`, …, default 1; ×0.75 for its own `pirate` race, ×1.5 for `xenon`); its levels.
- **Levels:** a list of `table[$standing, $maxsize, $cut]`, the standing needed for each level, the largest ship size it takes and its fence cut. The defaults start from the [time targets](../research/booty.md#levels-and-thresholds): about 20 levels, with M at about 6M standing, L at about 20M and XL at about 110M. The cut goes from 40% at level 0 down to 10% at the top. Each unlock names its own level, so "tiers of unlocks" is unlock data, not level data.
- **Stations:** found when needed, not listed: stations whose true owner is in the group's factions, `iswharf` or `isshipyard`, and that can dock the prize's size. Stations can be destroyed or change hands.
- **State per game:** `global.$APiratesLife_Groups.{$id}` = `table[$standing, $booty, $unlocks]`. Standing only goes up; booty goes up and down; `$unlocks` lists the unlocks bought.

### Handing a prize over

- **Two ways in:**
  - **The order:** "Hand over as booty", an order on a player-owned ship (`aiscripts/order.apirateslife.handover.xml`). It docks at the nearest group station that can take the ship, then asks for the handover.
  - **The station manager:** at a group station, the conversation lists the player's ships docked there that qualify, to hand over one at a time.
- **Who qualifies:** a player-owned, operational ship that the player isn't flying, whose size the player's level accepts. Ships with the player or the player's ship docked on them don't qualify.
- **The handover:**
  1. Move the pilot to a free marine slot on the nearest player ship (vanilla reassignment). With no free slot, the pilot goes with the ship, as in a sale.
  2. Ask our Lua for `GetTotalValue(ship, true, station)`: the price a vanilla sale there would pay.
  3. Credits: price × (1 − the level's cut), paid with `TransferMoneyToPlayer`. The ship goes with `C.SellPlayerShip`, the same as a sale.
  4. Booty: price × taste × (stolen bonus if pirated). Standing: booty × the standing gain setting. A level-up shows a notification.
  5. Rep with the station's owner goes up, unless the relation is locked. The amount is a setting; the default is an open question below.
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

In `md/apirateslife_config.xml`, under Tuning, as the settings bullet in DESIGN.md lists: standing gain, the fence cut's start and floor, the stolen bonus, the variant price, unlock and blueprint cost multipliers, the rep per handover. The level thresholds stay in the profile. Which of them go on the settings page is decided by the page's [rule](in-game-settings.md#design).

## Tasks

- [ ] Profile library, group state, and the handover by conversation and by order, with the Lua sale bridge
- [ ] Variant list, generator with its tests and sync check, the first set of variants
- [ ] Unlock conversation and blueprint unlocks
- [ ] Settings in the config file, with tests

## Done when

The scenarios in [`tests/game/features/booty.feature`](../../tests/game/features/booty.feature) pass, and in Erik's game a captured ship handed over at the Vigor wharf pays credits and booty, and an unlocked variant can be bought there and built and delivered.

## Open questions

- **Rep per handover:** how much vanilla rep a handover gives. Proposal: scaled by the booty, like vanilla mission rewards, about +1 UI point per 1M at first.
- **The recipes and the first set:** a design proposal with the variants PR.
- **In game, before or during the first PR:** whether `C.SellPlayerShip` works on a ship that docked by order while the player is elsewhere; at what relation Vigor stops docking and trading; whether Vigor's own ships start using our variants; whether Vigor has a station manager to talk to at both stations.
