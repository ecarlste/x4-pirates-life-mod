# Prior art: Better Piracy

**Status: complete for Better Piracy Reborn 14.10.** Every script, patch and library was read in full (2026-10-19); only the non-English text, voice files and preview images were skipped. Bugs marked *(suspected)* come from reading the code and haven't been reproduced in game. The related mods at the end are still unstudied.

**Read only.** The original repository has no license, so none of this code can be copied into our mod. We study what it does and how, then write our own.

File references like `harass.xml:391` point into the local snapshot of Reborn: `md/betterpiracy_harass.xml`, `md/betterpiracy_custom_bail_logic.xml` (`bail_logic.xml` below), `md/betterpiracy_config.xml`, `aiscripts/betterpiracy.order.fight.harass.xml` (`order.harass.xml`), `aiscripts/betterpiracy.order.fight.corsair.xml` (`order.corsair.xml`).

## Versions

| Version | Where | Target | Notes |
| --- | --- | --- | --- |
| Better piracy (original) | [GitHub](https://github.com/AlbertoRota/x4-Better-piracy), [Workshop 2056100433](https://steamcommunity.com/sharedfiles/filedetails/?id=2056100433), [Nexus 491](https://www.nexusmods.com/x4foundations/mods/491) | 3.x | By AlbertoRota. Author declared it dead (Mar 2025). |
| Better Piracy Reforged | [Nexus 2046](https://www.nexusmods.com/x4foundations/mods/2046) | 8.00 | Fork, v8.00.3 (Apr 2026). Now hidden by its author as unsupported. |
| **Better Piracy Reborn** | [Workshop 3816572322](https://steamcommunity.com/sharedfiles/filedetails/?id=3816572322) | **9.x** | By Jayseun, v14.10 (2026-10-09). Ports fixes from a 7.0 maintenance fork. Requires SirNukes' Mod Support APIs. |

Local snapshots (not in git): `E:\x4-dev\reference\mods\better-piracy-original\` (git clone) and `…\better-piracy-reborn-14.10\unpacked\` (Workshop catalog unpacked with XRCatTool). X4 installs Workshop mods straight into the game's `extensions\` folder, and Reborn ships as `ext_01.cat`/`.dat`.

## Feature catalog

| # | Feature | Files |
| --- | --- | --- |
| 1 | **Harass** operation: right-click action that forces a bail through a phased mission | `harass.xml`, `bail_logic.xml` |
| 2 | **Harass bail logic**: its own bail roll, every 10 s, bypassing vanilla | `bail_logic.xml` |
| 3 | **Pirate gang**: the player's subordinates join a Harass | `harass.xml`, `order.harass.xml` |
| 4 | **Corsair** default order: fleets find targets and Harass them on their own | `order.corsair.xml` |
| 5 | **Combat bail tweak**: patch to vanilla's bail formula and aftermath | `md/notifications.xml` (diff) |
| 6 | **Surrender removed** from vanilla comms | `md/conversations.xml` (diff) |
| 7 | **Marine claim tweaks**: travel drive, no orbiting, no claim damage | `aiscripts/move.claim.xml` (diff), engine macro (diff) |
| 8 | **Config menu**: 21 options | `config.xml`, `t/` |
| 9 | **Experience** for harassing ships | `libraries/experiences.xml` |
| 10 | **Threat voice lines**: 9 synthesized lines | `voice/`, `libraries/sound_library.xml` (diff) |
| 11 | Feedback: notifications, logbook, stats, debug file | spread |
| — | *Advertised but off:* piracy reputation hit; *removed in 1.4.1:* allies refusing fleeing ships dock | |

### 1. Harass operation

- **Entry:** the Interact Menu API's right-click menu shows "Harass" on any ship that is a ship, has a pilot, is operational, capturable, not player-owned, not a unit or laser tower, and only while the player has no active raid mission (`harass.xml:5-29`). The Corsair order can also start one with a `'corsair_init_harass'` signal on `player.entity`; those runs have no player mission (`$HasMission = false`).
- **State machine** (root cue `Harass_OperationCreated`, `namespace="this"`): phases DamageShields → DamageHull → ChaseTarget → WaitForSurrender → Claim → Finish. `Harass_ChangePhase` cancels the current phase cue and signals the next. Each phase has a 1 s `checkinterval` sub-cue.
- **Checks** (libraries, `harass.xml:93-160`), and any failed check **rolls the operation back**:
  - *Target*: finishes if the target isn't operational, is docked, the harasser isn't operational, or they're in **different sectors**. Goes to Claim if the target is ownerless, Finish if player-owned.
  - *Shields*: back to DamageShields if shields ≥ `harass_shield_threshold` (20%). DamageShields itself only completes at threshold − 10 (10%), a hysteresis band.
  - *Hull*: back to DamageHull if hull ≥ the current threshold. The threshold **tightens with attempts**: early 75%, mid 50% after 3 attempts, late 25% after 6.
  - *Distance*: back to ChaseTarget unless the player or a helper is within 3 km (S/M) or 6 km (L/XL).
  - *Crew* (capital ships only): goes to Claim (shown as "Board") once crew ≤ capacity × (25% + 25% × (15 − morale)/15).
- **WaitForSurrender:** every `keep_pressure_timer` (10 s, minimum 5): +1 `$Pressure`, +1 `$BailAttemps`, the player's ship computer speaks a random threat line, and the bail logic (§2) runs (`harass.xml:386-395`).
- **UI:** a player mission of type `raid` with one objective per phase, each with a **progress bar** (shield damage, hull damage, time to the next check). This is the best UX idea in the mod.
- **Claim:** S/M ships get the objective "The ship was abandoned" (claim); L/XL get "Begin a boarding operation". The mod doesn't claim or board itself; the player does. Ends when the ship is player-owned or destroyed.
- **Finish:** signals helpers to stop, and `remove_mission type="completed"` whatever the outcome.

### 2. Harass bail logic (`bail_logic.xml`)

A stripped-down copy of vanilla's `PlayerOwnedShipAttacks`, run 5 s after each pressure cycle:
- **Chance** = `harass_base_bail_chance` (60) × morale factor `(15 − effective morale) / 15` × shield/hull ratio (attacker vs. target, capped at 1) × 0.5 for capital ships. Effective morale = pilot morale − pressure × `pressure_buildup_rate` (1), floored at 0. So **morale melts by 1 per 10 s**; after ~150 s any pilot rolls at the full 60%.
- **Crew leaving** = max(20% of crew, 3) × morale factor, clamped to 1…crew count. If that covers everyone on an S/M ship, the pilot bails too. Capital ships never pilot-bail; they go to boarding.
- **Pilot bail aftermath:** logbook entry; `Wait` default order, `cancel_all_orders`, `cease_fire`, `eject_npcs`; removes 80–100% × (pilot skill / 100) of each cargo ware; optionally drops hull to (100 − skill)%; optionally destroys up to skill/10 weapons and turrets (shields spared for VRO compatibility); `stat.pilots_bailed` +1.
- **No vanilla gates, no vanilla cooldown**, no `'player_owned_forced_bail'` signal.

### 3. Pirate gang (`order.harass.xml`)

Each of the main harasser's subordinates (captured once, at creation) gets the internal `Harass` order. The order listens for signals **on the target object** and switches between:
- **attack**: vanilla `order.fight.attack.object` on the target, all weapons, no other targets.
- **chase**: cease fire, tell turrets (`defencenpc`) to stop, fly to the target every 2 s.
- **end**: cease fire and finish.

It starts in attack, whatever the phase.

### 4. Corsair order (`order.corsair.xml`)

- **Params:** area (sector position) and radius (up to radar range); target S (off), M (on), combat (off), traders (on), miners (on). Requires piloting skill 60 (3 stars). Meant to be a **default** order.
- **Loop:** move to a random safe position in the zone; interrupt when gravidar sees a capturable, undocked ship in the radius that matches the classes, has a purpose in the filter, and whose owner the corsair's faction relates to **below neutral** (hostile), not itself or ownerless. Then signal `'corsair_init_harass'` and fly on. A 30% resupply check every 30 min.
- **Hand-off:** the MD operation gives the corsair a `Harass` order (queued) and its subordinates too, and gives the **target** an `Attack` order on the corsair with chance = corsair pilot's piloting skill × 100 / 15.

### 5. Combat bail tweak (vanilla `notifications.xml` patch)

Replaces the first `$ejectchance` line with `(combat_base_bail_chance (36) − combinedskill/5) × shield/hull ratio`: drops vanilla's hull-size ratio; vanilla's ÷4 / ÷2 / ÷3 remain. Adds a crew-bailed notification for the player's own ship, and options to skip the pilot-bail hull drop (`$damageminpercent = 100`) and component sabotage. Selectors all resolve to exactly one element in 9.00.

### 6. Surrender removed (vanilla `conversations.xml` patch)

Removes the two `add_player_choice` entries (`g_surrender`, `g_surrender_nope`) from `DefaultComm`; the rest of the dialog stays. Harass replaces it.

### 7. Marine claim tweaks

- `move.claim.xml` diff: removes both claim-damage blocks (`$damagemaxpercent gt 0`), disables the orbiting `move_to`, removes `disable_collision_response`, and replaces the drone-attach approach with a travel-drive `move_to` that stops on collision.
- Engine macro diff: adds a `<travel>` drive to `engine_arg_xs_pv_01_macro`, the marines' personal vehicle, so the travel-drive approach works.

### 8. Config menu (SirNukes' Simple Menu API)

All values start `null` and are only filled when Simple Menu registers them (`config.xml:13-35`). Category "Better Piracy Reborn":

| Option | Default | Range | Effect |
| --- | --- | --- | --- |
| Harass shield threshold | 20% | 0–100 | Shields above this roll back to DamageShields; that phase ends at threshold − 10 |
| Early / mid / late harass hull threshold | 75 / 50 / 25% | 0–100 | Hull above this rolls back to DamageHull |
| Bail attempts before mid / late | 3 / 6 | 1–100 | When the hull threshold tightens |
| Keep pressure timer | 10 s | 5–30 | Seconds per pressure cycle and bail check |
| Keep pressure max distance S/M / L/XL | 3 / 6 km | 1–15 / 1–30 | Range needed to keep pressure |
| Pressure build-up rate | 1 | 0–3, step 0.25 | Morale lost per pressure point |
| L/XL min crew left, base / pilot | 25 / 25% | 0–100 | Crew level at which a capital ship goes to boarding |
| Harass base bail chance | 60% | 0–100 | Best-case chance per check |
| Harass base bail number | 20% | 0–100 | Best-case share of crew leaving per success |
| Harass / combat reputation hit | on | toggle | **No effect**: code disabled |
| Harass / combat bailing pilots damage hull | on | toggle | Pilot-bail hull drop |
| Harass / combat bailing pilots destroy components | on | toggle | Pilot-bail sabotage |
| Combat base bail chance | 36% | 0–100 | Replaces vanilla's 46 base |

### 9–11. Experience, voice, feedback

- **Experience** `BETTER_PIRACY_HARASS`: piloting, engineering and morale (individual and group, limit 25). Given to the Corsair lead (1.0) and helpers (0.8) on Claim; not to the player's own ship.
- **Voice:** 9 synthesized threat lines ("The battle is over, abandon your ship immediately!", "You stand no chance, be smart, and surrender."…), spoken by the player's ship computer each pressure cycle, through a filtered "comm" sound.
- **Feedback:** crew-bailed notifications, logbook entry on pilot bail, `stat.pilots_bailed`, a "Better Piracy Reborn installed" help message on every new game, and a detailed `debug_to_file 'BetterPiracy'` log.

## Bugs and weaknesses

| # | Problem | Evidence | Impact |
| --- | --- | --- | --- |
| 1 | **Corsair's Harass order only runs if Corsair is the *default* order.** `create_order` without `immediate` queues behind the current order, and Corsair is infinite | `harass.xml:227`, `order.corsair.xml:3` | Assigned as a normal order, the corsair "flies around but does nothing" (matches player reports) |
| 2 | **Corsair only targets hostile factions** (`relation lt neutral`); with defaults (M only, traders/miners only) targets are rare | `order.corsair.xml:150` | Long idle patrols |
| 3 | **Corsair captures are never claimed.** For corsair runs, Claim jumps straight to Finish | `harass.xml:427-429` | Bailed ships drift ownerless unless a ship happens to have vanilla's claim response |
| 4 | **Duplicate operations:** Corsair doesn't check whether a target is already harassed, and keeps scanning every 0.5 s | `order.corsair.xml:131-184` | Several overlapping operations, orders and voice lines on one target *(suspected)* |
| 5 | **Helpers attack at full strength** in the shield/hull phases, with no weapon choice and no easing near the threshold; phase checks run once a second | `order.harass.xml:59-65` | Fleets kill the prize |
| 6 | **Crew-bailed notifications for every operation**, including Corsair runs anywhere in the galaxy | `bail_logic.xml:83-87` | Notification spam |
| 7 | **Pilot skill read after `eject_npcs`** for cargo removal, hull drop and sabotage | `bail_logic.xml:127-151` | Likely null values, so those effects misfire *(suspected)* |
| 8 | **Sabotage ignores vanilla's "never destroy mandatory equipment" filter** | `bail_logic.xml:149` | Can destroy equipment vanilla protects |
| 9 | **Every ending reports "completed"**: escape, destruction, abort | `harass.xml:442-455` | No failure feedback |
| 10 | **Distance check counts the player** even for Corsair runs | `harass.xml:137-139` | A corsair op advances because the player is nearby |
| 11 | **Helpers fixed at creation;** new subordinates never join | `harass.xml:72` | |
| 12 | **The operation ends if the target changes sector** | `harass.xml:95` | Targets escape through a gate |
| 13 | **The target fights back based on the *corsair's* skill** (`piloting × 100 / 15`) | `harass.xml:231` | Better corsairs provoke more resistance, which seems backwards |
| 14 | **The config is `null` until Simple Menu registers it**; a broken or missing SirNukes install leaves every threshold null | `config.xml:13-35` | The whole mod misbehaves with no clear error |
| 15 | **Two reputation toggles do nothing**, and the README still advertises a removed feature (allies refusing fleeing ships) | `bail_logic.xml:116-119`, README | Misleading menu and docs |
| 16 | **Bypasses vanilla's bail path entirely**: no gates, cooldown, `'player_owned_forced_bail'` signal, or claim-response condition | `bail_logic.xml` | Other systems (including our `Bailed` signal and notoriety) never see Harass bails |
| 17 | **The player's own ship gets no experience** from a Harass | `harass.xml:410-413` | |

## Compatibility with A Pirate's Life

- **Same vanilla cue.** Both mods patch `PlayerOwnedShipAttacks`. Ours inserts a hook after vanilla's modifiers; theirs replaces the base line. The replaced element keeps `name="$ejectchance"`, so both may apply; unverified.
- **Harass bypasses our hook** (bug 16), so with both installed, notoriety and the `Bailed` signal miss most bails.
- **Surrender:** they remove vanilla's comm option; our design may keep or extend it.
- We're likely to declare it incompatible, but our patches should fail gracefully when it's installed.

## How we'd do it better (and more watchable)

Keep what works, fix what doesn't, and design for moments a viewer can follow:

- **One bail path.** Pressure, threats and fleet raids all feed vanilla's bail check through our hook, so notoriety, fear vs. honor, the `Bailed` signal and other mods see every bail. No copied formula to keep in sync.
- **A visible nerve meter.** Keep Harass's progress-bar idea, but show the target pilot's *nerve* (morale minus pressure, modified by our notoriety) on the target. A creator can say "one more push and he breaks", and viewers can see it.
- **Threats as choices, not a timer.** Instead of a random line every 10 s, the player picks a comm approach (intimidate, offer mercy, demand cargo) that feeds fear vs. honor and changes how the pilot reacts. A feared pirate's threats land harder; an honorable one's offers are trusted. That's dialogue and drama, not just a countdown.
- **Real outcomes, each with feedback:** surrendered, bailed, escaped, destroyed (prize lost), or cargo dumped. Each has its own notification and logbook entry, so a video has a clear beat at the end of every encounter.
- **Wingmen that capture, not kill.** Hold fire at the hull threshold, prefer ion or shield-only weapons, "disable engines" and "surround and hold" commands (already in our design). No more "my wing killed the prize".
- **Raid Sector, done right.** Targets neutral traffic too, with heat as the cost; sets the fleet's `foundabandonedship` response to `claim` so prizes are actually taken; prize crews fly them home; no duplicate operations; and a **raid report** at the end (ships taken, cargo, losses, heat gained) that makes a good end-of-episode recap.
- **Consequences that are on.** Reputation, heat and bounty hunters instead of disabled toggles: the tension that turns raids into a story.
- **Captures arrive intact by default** (already built: [claim-no-damage spec](../specs/claim-no-damage.md)), with sabotage brought back only as a fear vs. honor consequence.
- **Robust config.** Sensible built-in defaults that work even if a UI dependency fails, with the menu only overriding them.

## Related mods

Found while researching Better Piracy. The descriptions come from search results and haven't been checked against the mods' files yet.

| Mod | What it does | Status |
| --- | --- | --- |
| True Capture ([Nexus 97](https://www.nexusmods.com/x4foundations/mods/97)), vx | Inspiration for Better Piracy | Reported broken since 7.0 |
| Fix Bail Logic ([Nexus 87](https://www.nexusmods.com/x4foundations/mods/87)), Kevrlet | Bail based on relative hull health, attacker vs. target class difference and target morale; 5% base; L/XL can bail at 50% of the normal rate. Install folder `fixbailchance` | Last updated May 2021 |
| Enhanced Bailing ([Nexus 741](https://www.nexusmods.com/x4foundations/mods/741)) | Credits Fix Bail Logic. A 9.x variant (`enhanced_bailing_9x`) reportedly covers NPC-vs-NPC abandonment and surrender demands for any ship size | **Most relevant to check next** |
| Better Capture ([Nexus 1406](https://www.nexusmods.com/x4foundations/mods/1406)), Gryzli100 | No hull or component damage from bailing crew or marine claims | Made after True Capture broke |
| No Bailing Penalty ([Nexus 1725](https://www.nexusmods.com/x4foundations/mods/1725)) | Not checked | |
| Bail and Board ([Nexus 1828](https://www.nexusmods.com/x4foundations/mods/1828)) | Not checked | |

## Open questions

- Confirm the *(suspected)* bugs in game: duplicate Corsair operations (4) and the pilot skill read after ejection (7).
- What the related mods do in detail, starting with Enhanced Bailing's 9.x variant.
