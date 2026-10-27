# Pirate variants: which ships and gear, and how they're rigged

**Status: partly agreed (Erik, 2026-10-27).** The booty v1 design says the first variants start small, and that their recipes go to Erik as a design proposal ([DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing); [spec](../specs/booty.md#variants)). This note is that proposal: how a pirate operates, which vanilla hulls suit it best at each size, what a "pirate rig" changes, and a first set.

- **Agreed, now in DESIGN.md:** hulls by pirate role; the core set from base and Tides of Avarice only, other DLCs as extras; pirate gear (combat, all-round and travel engines, quick-recharge shields, the Stripper built on vanilla's ion blaster, a pirate EMP missile at about level 3); the first set; names ("Pirate" for pirate versions of existing tech, fun names for new things).
- **Still iterating:** the rig recipes. Cargo should stay valuable on some builds: booty for cargo turn-ins is coming later (see Ideas).

Data: every ship macro in X4 9.00 (base and all DLCs, 285 ships), read from the unpacked files under `E:\x4-dev\reference\x4-9.00\` with a throwaway script. The **speed index** is engine slots ÷ forward drag × 100: it ranks ships of one size by how fast the same engines push them, for both combat and travel speed. It isn't a speed in m/s.

## How a pirate operates

A pirate doesn't win by out-gunning a patrol. They pick fights and leave before help comes:

1. **Catch.** Traders flee, and in travel mode. A raider needs top travel speed and quick travel acceleration to run them down, then enough guns to strip shields fast without killing the prize.
2. **Take.** A pilot bails under pressure from many ships, and boarding needs marines. So: swarms of small, cheap ships (they break shields from every side, keep the bail gate open, and cost little to lose), and roomy hulls to carry marines.
3. **Keep.** A prize has to get home. A hull with a dock for small ships can carry a captured fighter home with no prize crew. A hull that repairs docked ships raises the prize's booty before handover (only the hull's share of the price, so a few percent for a fitted fighter, more for big ships: [booty research](booty.md#to-verify-in-game)).
4. **Run.** Police and military answer the distress call. Travel speed and boost get a pirate out; cargo space carries the loot they scooped.

So the best pirate ship of a size is rarely the strongest warship. It's the fastest, the roomiest, or the one that can carry and fix prizes.

## Only Tides of Avarice is required

The mod requires Tides of Avarice and nothing else ([PROJECT.md, Key decisions](../PROJECT.md#key-decisions)). A variant of a Split or Boron hull would only exist for players who own that DLC. So each pick below has a base-game or Tides of Avarice hull; hulls from other DLCs are extras the profile adds only when that DLC is installed.

## Findings from the data

- **Every M frigate is already a mini-carrier:** one external S pad plus internal storage for one S ship (`dockarea_*_s_ship_01` and `shipstorage_gen_s_frigate_01`). A frigate can take a captured fighter aboard and fly it home.
- **Only ships with a build module repair the ships docked at them** (`issupplyship`: "can repair ships and equipment"; `buildmodule_gen_resupplier_macro`). That's every XL carrier and resupplier, and two L ships: the Boron **Guppy** carrier (16 S docks, 60 crew, Boron DLC) and the Paranid **Hyperion** (3 S docks, 106 crew, 6 guns and 8 turrets, Hyperion Pack). No M ship can repair. Adding a build module to an M hull would mean a new component with a new connection: possible, but a spike of its own (see Ideas).
- **Transports carry crew.** A cheap M transport holds as many people as a frigate, and an Argon L freighter up to 225: room for marines. Some are fast for their size.
- **M ships launch boarding pods** (Erik's games): he regularly takes L ships, the Erlking included, with a group of captured M transports full of marines and no L ships at all. So a swarm of boarding transports is a whole boarding fleet, and the cheapest one.
- **Pirate factions already fly suitable hulls:** Vigor's **Lux** (the fastest gunned S fighter in base and Tides of Avarice) and **Kyd** (the cheapest fighter Vigor sells), and the Yaki **Moreya** and **Kuraokami** (Terran DLC).

## The candidates, by role

Base game or Tides of Avarice unless marked.

| Role | Hull | Size | Why | Key numbers |
| --- | --- | --- | --- | --- |
| Raider | Vigor **Lux** (`ship_pir_s_fighter_02_a`) | S | Fastest gunned S fighter without other DLCs; Vigor's own | 3 guns, speed index 75.6, 500 cargo, 175k |
| Raider (extra) | Yaki **Moreya** (`ship_yak_s_fighter_01_a`, Terran DLC) | S | A pirate faction's fighter: fast and well armed | 4 guns, speed index 95.7, 510 cargo, 269k |
| Swarm skiff | Vigor **Kyd** (`ship_pir_s_fighter_01_a`) | S | Cheapest fighter; a dozen cost less than one corvette | 2 guns, speed index 50.6, 650 cargo, 53k |
| Swarm skiff (extra) | Boron **Irukandji** (`ship_bor_s_scout_02_a`, Boron DLC) | S | Fastest buildable small ship, cheap | 2 guns, speed index 133.6, 120k |
| Prize runner | Paranid **Gorgon** (`ship_par_m_frigate_01_a`) | M | Fastest base frigate; carries a captured S ship home; 16 crew | 2 S docks, 3 guns + 4 turrets, speed index 26.4, 1.1M |
| Prize runner (extra) | Split **Cobra** (`ship_spl_m_frigate_01_a`, Split DLC) | M | The best frigate for this: fastest, toughest, 25 crew | 2 S docks, 33k hull, speed index 34.9, 2.2M |
| Boarding transport | Paranid **Hermes** (`ship_par_m_trans_container_02_a`) | M | 20 crew for 177k: the cheapest way to move marines | 20 crew, 7,100 cargo, speed index 19.6 |
| Armed boarding transport | Paranid **Prometheus** (`ship_par_m_trans_container_03_a`) | M | A fast transport that fights back | 12 crew, 4 guns + 3 turrets, speed index 28.6, 292k |
| Raider flagship | Vigor **Barbarossa** (`ship_pir_l_scavenger_01_a`) | L | Vigor's own L, among the faster L hulls, 126 crew | 14 turrets, 3 S docks, 21,000 cargo, speed index 4.6, 7.7M |
| Boarding freighter | Argon **Sonra** (`ship_arg_l_trans_container_05_a`) | L | Fastest Argon L freighter; 178 crew and 8 S docks | 9 turrets, 29,000 cargo, speed index 3.1, 3.6M |
| Repair tender (extra) | Paranid **Hyperion** (`ship_par_l_expeditionary_01_a`, Hyperion Pack) | L | The only L that repairs docked ships and carries 106 crew | build module, 3 S docks, 6 guns + 8 turrets, 3.1M |
| Swarm carrier (extra) | Boron **Guppy** (`ship_bor_l_carrier_01_a`, Boron DLC) | L | 16 S docks that repair: a mobile base for a swarm | build module, 60 crew, 16 turrets, 6.5M |
| Mothership | Paranid **Atlas** resupplier (`ship_par_xl_resupplier_02_a`) | XL | Repairs docked prizes; docks 32 S and 6 M; 258 crew | build module, 56,100 cargo, 15.5M |

## Pirate rigs (the recipes)

A variant is a copy of the vanilla macro with some properties scaled, sold by Vigor at the vanilla price × the price setting (×1.25 by default). What a macro can change: hull, crew capacity, drag (all speeds), mass, acceleration (`jerk`, travel included), missile storage, and cargo (through a copied storage macro). Weapon, turret and dock slots belong to the model, so they stay.

Each role gets a trade-off, so a variant is better at piracy and worse at something else:

| Rig | Drag (speed) | Travel acceleration | Hull | Crew | Cargo | Trade-off |
| --- | --- | --- | --- | --- | --- | --- |
| Raider | ×0.85 (about +18% speed) | ×1.25 | ×0.85 | — | ×1.5 | fragile |
| Swarm skiff | ×0.9 | ×1.25 | ×0.8 | — | — | very fragile, cheap to lose |
| Prize runner | ×0.9 | ×1.15 | ×0.9 | ×1.25 | ×1.5 | thinner armour |
| Boarding transport | ×0.9 | ×1.15 | ×1.1 | ×1.5 | ×0.6 | less cargo for more marines |
| Flagship / freighter | ×0.85 | ×1.2 | ×0.9 | ×1.25 | ×1.25 | thinner armour |
| Mothership | ×0.8 | ×1.2 | ×0.9 | ×1.2 | — | thinner armour |

### Gear

- **Pirate engines, all three types** (agreed; Erik asked for combat and all-round as well as travel, so players can tailor a ship). Each is a bit better at catching and fleeing and pays with a more fragile engine. Engine thrust lives in the engine macro, so each is a copied engine:

  | Pirate engine | Combat thrust | Travel thrust | Boost | Trade-off |
  | --- | --- | --- | --- | --- |
  | Combat | ×1.1 | ×1.15 | ×1.15 | engine hull ×0.8 |
  | All-round | ×1.05 | ×1.2 | ×1.15 | engine hull ×0.8 |
  | Travel | ×0.9 | ×1.3 | ×1.1 | weaker in a fight |

- **The Stripper** (agreed; the name stays): a gun built to strip shields, with heavy shield damage and light hull damage, so the bail gate opens fast and stray shots barely scratch the prize ([pirate-refitting.md](pirate-refitting.md#raid-a-faction-arm-from-its-enemies) had the idea first). **Built on vanilla's ion blaster** (agreed), which already does about 4× more shield than hull damage (S Mk1: 268 shield, 68 hull; `bullet_arg_s_ion_01_mk1`). The Stripper pushes that to about 8:1 (shield ×1.3, hull ×0.6). S and M, Mk1 and Mk2, the marks vanilla's ion comes in.
- **Shields:** a quick-recharge rig (recharge delay ×0.7, capacity ×0.85), for hit-and-run.
- **A pirate EMP missile** (agreed, about level 3). Vanilla's EMP missile (base game) does 1 damage and shuts down boost and travel drive for 30 s on S and M ships, 18 s on L and XL (`emp_missile` in `libraries/influenceconfigurations.xml`): the missile that stops prey running. A pirate one shuts them down ×1.5 longer (45 s on S and M), at about level 3, and gets a fun name, as something new (e.g. "Cold Feet"). The Split DLC's disruptor missile does the same plus halved acceleration, with 896 damage.
- **No vanilla weapon damages components more than hull.** Damage is only shield or hull (`<damage value shield hull>` in the bullet macros); turrets and engines on L and XL are surface elements that can be targeted, but every weapon hurts them alike. A disabler for big captures needs a spike (see Ideas).

## A first set to propose

Small, to prove the generator and the unlock flow, and still a whole pirate career:

| Unlock | Level | Why first |
| --- | --- | --- |
| Pirate Kyd (swarm skiff) | 1 | Cheap, early, and swarms fit the bail mechanics |
| Pirate Lux (raider) | 2 | The fast S raider |
| Pirate strippers, S, Mk1 | 2 | The capture weapon |
| Pirate travel engine, S, Mk1 | 3 | Catch and flee |
| Pirate Hermes (boarding transport) | 4, with M turn-ins | Marines, cheap |
| Pirate Gorgon (prize runner) | 6 | Carries prizes home |
| Pirate strippers and travel engines, M, Mk1 | 6 | M kit |
| Pirate Barbarossa (raider flagship) | 9 | First L |
| Pirate Atlas (mothership) | 16, with XL turn-ins | Repairs prizes before handover |

Mk2 and Mk3 of the gear follow at higher levels; the DLC extras slot in beside their base picks when the DLC is installed.

## Ideas, not part of the proposal

- **A repair bay on an M hull:** an M mini-carrier that repairs the fighters docked on it, like the Star Wars Interworlds cruiser that carries four fighters. Needs a copied component with a build module connection; a spike first.
- **Smuggler's hold:** a higher `secrecy` level on pirate variants, so police scans read less of the ship. Whether secrecy affects cargo scans at all is to check.
- **False colours:** fly under another faction's identification for a while. Far out; needs research.
- **Decoys and mines** for chases: vanilla has both; a pirate rig of them could cover a getaway.
- **Swarm orders:** a capture operation that sends a whole swarm from a carrier, then recalls it; ties in with the operation queue in the plan.
- **Booty for cargo** (Erik, 2026-10-27, later): turning in cargo for booty, mostly from missions, and high-value cargo a target is made to jettison for a big payout. Keeps cargo valuable on some pirate builds, so the rig recipes shouldn't cut it everywhere.
- **A disabler for L/XL captures:** a weapon or missile that knocks out turrets and engines without hurting the hull, for taking big ships whole. Vanilla has no damage type for it; a spike first.
- **EMP limpet mines** (`bomb_player_limpet_emp`, vanilla) for a getaway or an ambush kit.

## To check in game

- Speed index against real speeds for a few picks, with the same engines.
- Whether a captured S ship can dock in a frigate's internal storage after the claim, and stays aboard safely.
- Whether docked prizes are repaired at an Atlas by an order, how fast, and at what cost.
- Whether the Hyperion Pack is installed for every player of 9.00, which would make the Hyperion a base pick.
