# Capture operations and kuertee's emergent missions under SWI

**Status: done (2026-11-11), from the files only; nothing run in game.** Answers [#107](https://github.com/ecarlste/x4-pirates-life-mod/issues/107): on X4 8.00 with SWI 0.91 HF1, does a [capture operation](../specs/capture-operation.md)'s fighting count as a crime against the player, or put a bounty on them, through kuertee's emergent missions (kEM) or any other SWI crime, bounty or police logic? Follows [swi-capture-ui.md](https://github.com/ecarlste/x4-pirates-life-mod/blob/research/swi-capture-ui/docs/research/swi-capture-ui.md#no-missiles-patch-fightattackobjectfighterxml) (#105), which found SWI's kEM hooks on `order.fight.attack.object` and left this question open. It lays out what happens and the options. Whether any of it is a feature or a bug is Erik's call.

Sources:
- **Vanilla 8.00:** `E:\x4-dev\reference\x4-8.00\`, below `V:` (`V:base\…`).
- **SWI 0.91 HF1:** `E:\x4-dev\reference\mods\swi-0.91hf1\ext02\` (`ext_02.cat` unpacked), below `S:`. kEM ships there as `S:md\kuertee_emergent_missions.xml` (12,707 lines), with its AI hooks in `S:aiscripts\kuertee_em_interrupts.xml`. kuertee's professions are `S:md\kuertee_professions.xml`.
- **Ours:** `origin/main` at `037fa62`: `aiscripts/order.apirateslife.capture.xml`, `md/apirateslife_capture.xml`.

**Fact** means read in those files. **Inference** means it follows from them but depends on engine behaviour the files don't show; each one says what would settle it.

## Short answer

- **No crime, no bounty from a capture that ends in a bail.** kEM only puts someone on its bounty list for a **kill**. A bailed prize is ownerless but still operational, so it never counts. The relation boost, the bail and the claim have no kEM listener at all.
- **A destroyed prize can put the player on SWI's bounty-hunter list.** If a wingman's attack run that kEM picked up (a 25% roll per run under SWI) ends with the prize dead, kEM registers the kill against the **player's ship's pilot**, since wingmen are rolled up to their commander. SWI's ten named bounty-hunter jobs (Boba Fett, IG-88 and the rest) pick random ships from that same list and attack them. kEM's own bounty *missions* skip player-owned targets, but SWI's hunters don't check.
- **Police and faction relations are vanilla's, and SWI only softens them.** The wingmen's attacks reach the police through vanilla's distress-drone report, and the player's own shots through vanilla's `PlayerAttacks`. That's the same chain as vanilla's own "Mark as hostile" plus a wingman Attack order. SWI's only change makes kuertee's "sanctioned" targets exempt.

## How kEM sees a fight

SWI patches `order.fight.attack.object` (`S:aiscripts\order.fight.attack.object.xml`), the script our capture order runs for each firing run (`aiscripts/order.apirateslife.capture.xml:127`):

| Where in the script | kEM call | SWI line |
| --- | --- | --- |
| After `<label name="fight"/>` (vanilla `V:base\aiscripts\order.fight.attack.object.xml:744`) | `kEM_AttackStart` | 26–30 |
| After `<label name="acquirenewtarget"/>` (vanilla 1251) | `kEM_AttackFinish` | 34–38 |
| After `<label name="finish"/>` (vanilla 1279) | `kEM_AttackFinish` | 42–46 |
| In `<on_abort>` (vanilla 1333) | `kEM_AttackFinish` | 50–54 |

What those two do (`S:aiscripts\kuertee_em_interrupts.xml`):

- **`kEM_AttackStart`** (lines 6–42), fact:
  - It runs once per victim per script instance (`@$kEM_victim != $target`, line 9).
  - Both sides must be ships or stations, not units or laser towers (18–19).
  - Under SWI only **25%** of attacks count. `$IsSWIExists` is `@ware.tie_fighter != null`, which forces `$isUseFullMod` to false (`S:md\kuertee_emergent_missions.xml:230–232`), and then `$kEM_random le 25` (interrupts 22–24).
  - A counted attack saves the victim's faction, class and ID code and signals `K_ObjectAttacks_AttackerInit` on `player.galaxy` with `$attacker = this.assignedcontrolled` (the wingman) and `$victim` (30–36).
- **`kEM_AttackFinish`** (43–58), fact: if the run was counted and the victim is **not operational**, it signals `K_ObjectAttacks_AttackerKilledObject`. It doesn't check who landed the killing shot.

**Our order re-rolls often.** Every hold → fire cycle aborts the attack script (`abort_called_scripts`, our lines 50 and 62) and starts a fresh `run_script` (127). That's a new script instance, so `$kEM_victim` is unset again (inference: standard AI script variable scope) and the 25% roll comes again. Over a whole operation, some wingman's run almost certainly counts. That only matters if the prize dies during a counted run, because an abort while the prize is still alive goes through `on_abort` → `kEM_AttackFinish` with an operational victim, which does nothing.

**The player's own shots are invisible to kEM.** A ship the player flies runs no `order.fight.attack.object`, so only wingmen (and any other AI ship) feed kEM.

## Who listens, and what they do with it

### kEM missions' enemy tracking: excludes the player

`EnemyTargets_Accumulate` (`S:md\kuertee_emergent_missions.xml:8559–8674`) listens to `K_ObjectAttacks_AttackerInit` (8593–8611). Fact: it requires `not [faction.player, faction.civilian].indexof.{attacker.owner}` (8610, and 8590 for the plain attack events). Our wingmen are player-owned, so they're never added as a mission's enemy.

### kEM bounties: kills only, and the player's pilot can be listed

`Bounties` (cue at 11125) keeps a group `$pilots` of pilots with kills. Its global handle is `global.$Bounties` (11132).

- **`Bounties_NewAttack`** (11518–11553), on `AttackerInit`, fact:
  - An S/M attacker with an operational ship commander is replaced by that commander (11535–11538). For our wingmen, that's the player's ship.
  - It only *updates the last known location* of pilots already on the list (11539–11550). An attack alone registers no one.
- **`Bounties_TargetDestroyed`** (11554–11599), on `AttackerKilledObject`, fact:
  - It walks an S/M attacker up to its top-level ship commander and marks the kill as a subordinate kill (11571–11583).
  - Then `Bounties_RegisterPilot` adds `$attacker.pilot` to `$pilots` (11318–11373), and `Bounties_RegisterKill` adds **0.25** of a kill for a subordinate kill, 1 otherwise (11507–11512).
  - Its only exclusion is the victim's faction being on the no-bounty list (11562). Under SWI that list is Independent BHG, Sith, Xenon, Kha'ak, Hutt pirates, Mandalorian raiders, Valarian, Black Sun and Hapes (63). There's no player check.
- **Player pilots are expected on the list.** The clean-up gives player-owned pilots a 1 h expiry instead of 4 h (11760–11766, 11789; fact). Each further counted attack or a sector change seen by a station or satellite (`Bounties_ChangeSector`, 11600) refreshes the timer through `Bounties_UpdateLastKnown`.
- **Whose pilot it is.** `pilot` is "Pilot entity", and `assignedpilot` / `assignedaipilot` are the ones "which may not currently be piloting" (`V:base\libraries\scriptproperties.xml:303–306`). Inference: while the player flies the leader, `player.occupiedship.pilot` is the player entity, so the player is the one listed. If not, the listed pilot is still the leader's, and the hunters below target the pilot's ship, the same ship either way. A `debug_text` in game would settle it (`UserSettings.$debugChance_bounties`, which the chat command `debug hunt clean old beacons` turns on, 11749–11756).

### kEM bounty missions: never against the player

Bounty ("hunt") offers go through `Missions_Hunts_CreateOffer` (5218–5255), from the map (11966) and from the station conversation SWI uses (12185). Fact: it only offers a hunt when `not $target.isplayerowned` (5231). So no faction posts a kEM hunt mission on the player's ships.

One loose end, fact: the guild-network "mission nearby" flag (11836–11888) is computed over all `$pilots` with kills, the player included, before that filter. So it can say a bounty is nearby when there's none to take. That's cosmetic.

### SWI's bounty hunters: do hunt the player

`order.sw.bountyhunter.fighters` (`S:aiscripts\order.sw.bountyhunter.fighters.xml`), fact:
- Every 1–2 minutes it picks `global.$Bounties.$pilots.random.ship` (line 35). That's kEM's list above, with no owner check.
- It skips docked ships, L/XL ships and ships under an L/XL commander (43–54).
- Otherwise it runs `order.fight.attack.object` on the ship with `checkrelation="false"` and `forceprimarytarget="true"` (56–62).
- It's the default order of the bounty-hunter jobs (`S:libraries\jobs.xml:21508` on, e.g. `bountyhunters_ig`, quota 1 each). They're switched on 20–30 minutes into SWI's setup (`S:md\setup_swmod.xml:245–262`: IG, Neesh, Ketsu, Sabine, Embo, Dengar, Bane, Aman-a-man, 4-LOM, Boba, Asajj, Mando).

So once the player's pilot is on the list, any of these hunters may pick the player's S/M ship (one random pick among all listed pilots, every 1–2 minutes per hunter) until the entry expires an hour after its last update. Inference for the odds: it depends on how many NPC pilots are listed at the time, which the files can't tell.

### kEM bounty missions: a bail completes one

If the prize happens to be a kEM hunt target the player took, `Mission_Hunt_TargetManager_Destroyed` treats `event_object_abandoned` like destruction (6275–6309, fact). A bail completes the hunt. That works in the player's favour.

### kuertee's professions: player kills only

`Attacker_Event` (`S:md\kuertee_professions.xml:5749`) listens to `event_player_killed_object`, which is a kill "from their currently controlled object" (`V:base\libraries\common.xsd`, `event_player_killed_object`). It shares the kill out as mercenary, defender, vigilante or pirate reputation (5905–6095). A **pirate** reputation with a faction brings a 25% trade penalty at its stations (`Pirate_AddTradePenalty`, 5555–5600). The `Saboteur_Event`'s `event_player_attacked_object` only counts bombs (4786–4787). Fact: a bail or a claim feeds none of this. Only the player's own killing shot does.

## Police and relations

### Vanilla 8.00

Faction relations from an attack are applied by the engine for every attacker ("generic relation handling is done in code", `V:base\md\notifications.xml:1561`). The `IllegalActivity` cues add the player-facing warnings and police reports:

- **The player's own shots** (`PlayerAttacks`, 1500–1552), fact:
  - Its trigger is `event_player_attacked_object`: attacks "from their currently controlled object" only, not the wingmen's.
  - It skips ownerless targets (1503), so nothing counts once the prize has bailed.
  - It calls `change_relation_on_attack` (1517) and signals `AttackResponse`.
  - For an S/M victim, `AttackResponse` looks for a protective station within 30 km and radar range (1886–1941):
    - **With one:** a warning after 3 s (2002–2011). A **kill** is reported to the police (2040–2042).
    - **Without one:** nothing ("TODO", 2032–2034, 2053–2055).
- **The wingmen's shots** reach the police only through a **distress drone**:
  - The prize's `interrupt.attacked` "call for help" launches one, once per attacking faction. It needs a target that isn't a combat ship, isn't XS and isn't in a highway, an attacker that isn't a station or XS, a police faction in the zone that the target isn't hostile to, and no cover (`V:base\aiscripts\interrupt.attacked.xml:105–120`, launch at 250–263).
  - The drone flies to a station (`move.escapepod.xml`). If the attacker is still operational and the zone has a police faction, it signals `report_attack` (84–86, 194–196).
  - `DistressDroneReportsAttack` takes it only for a player-owned attacker (`notifications.xml:1554–1630`). `AttackResponse` reports it when the relation changed (2058–2063).
  - `IllegalActivityRetaliate` (2222–2258) then lowers the player's relation with the police faction and signals `'police'` in the sector against the attacker. It only does so if the attacker is still in the reporter's sector (2240).
- **The `'police'` signal** sends police ships after the attacker (`masstraffic.police.xml:70`, `move.seekenemies.xml:287`, `order.move.recon.xml:169`).
- **"Mark as hostile"** is `C.SetRelationBoostToFaction(component, "player", "markedashostile", -1, 1, 600)` (`V:base\ui\addons\ego_detailmonitor\menu_userquestion.lua:94`). Its only warning is "It might retaliate immediately." (text 1001/9710). Vanilla's way to have wingmen attack a neutral is this boost plus an Attack order, and that runs the same distress-drone chain.
- **Claims.** `PlayerBoarding` would report `'boarding started'`/`'boarding ended'` (1787–1846), but nothing in the 8.00 MD or AI scripts signals it (`grep "boarding started"` finds only `notifications.xml`). Our claim is of an ownerless ship anyway.

### What SWI changes

`S:md\notifications.xml:441–517` patches only the cues above:
- No relation penalty for a kill whose ID code is in kuertee's `$sanctionedKillIds` (450–459, 504–506, 516).
- A refusal instead of a report, and no police signal, for `$sanctionedAttackIds` (474–480, 507–510, 517).

Those lists come from kuertee's professions (missions and guild sanctions), not from anything a capture operation sets. SWI's `move.seekenemies.xml` and `order.move.recon.xml` add conditions after the `'police'` listeners (lines 30–46 and 40–43), and the `interrupt.attacked.xml` patch only adds Hapes raider calls (lines 4–23). Fact: SWI adds no new crime or police trigger.

### Our relation boost on top of that

Our op applies the same boost as vanilla's "Mark as hostile", without the `markedashostile` reason (`aiscripts/order.apirateslife.capture.xml:80`, `md/apirateslife_capture.xml:98`). It resets the boost on "called off" and "escaped" (`md/apirateslife_capture.xml:220`). Inference:
- With the prize at -1 to the player, `DistressDroneReportsAttack`'s `$relchange` (prize-to-player minus faction-to-player, 1575–1577) is non-zero, so a drone's report goes to the police (2061–2062).
- That would happen without the boost too, from the engine's attack penalty.

Whether `change_relation_on_attack` costs less against a target already at -1 isn't in the files. A game run that logs `$relchange` (the `debug_text` at 1579, `chance="0"`) would show it.

## Each trigger, with options

| Trigger | kEM / SWI | Vanilla 8.00 | Options |
| --- | --- | --- | --- |
| **Relation boost** (-1, 600 s) | No listener. kEM, professions and SWI never read relation boosts (`grep` finds none in the kuertee files). Side effect: kEM won't offer escort or raid missions from the prize while it's hostile (`kuertee_emergent_missions.xml:1024`, 2143) | Same as "Mark as hostile". Makes the prize hostile, so it can fight back and its distress drone's report counts | (a) Keep as is. (b) Pass `reason="relationchangereason.markedashostile"` (the UI's reason) so logs read the same as vanilla's; harmless either way |
| **Wingmen attacking a neutral** | 25% of firing runs signal `AttackerInit`. That only refreshes the location of pilots already listed, never lists anyone. kEM missions ignore player-owned attackers | Engine relation penalty per hit. One distress drone per faction can bring a police report, a relation drop with the police faction and police ships, if the wingman is still in the sector | (a) Accept: vanilla piracy costs the same. (b) Under SWI, keep wingmen out of kEM by not running `order.fight.attack.object` for them. That means our own combat, which failed before (spec, "Rejected or tried"). (c) Set the kEM variables ourselves: `$kEM_victim` is script-local to the attack script, so it would take a diff on SWI's own patch. Fragile |
| **Prize destroyed by a wingman's run** (the "Destroyed" outcome, or the player's kill landing during a counted run) | 25% chance per run that kEM registers 0.25 of a kill against the leader's pilot (likely the player). SWI's named bounty hunters can then target the player's S/M ship for an hour after the last update | Police report for killing a protected ship; relation penalty | (a) Accept as "piracy has consequences": rare, since the order holds at the burst margin and the 35% floor. (b) Avoid by keeping kills out of counted runs, i.e. option (b) above. (c) Embrace it on purpose: our own "Wanted" reading of `global.$Bounties.$pilots` could warn the player that they're listed |
| **Bail** | No kEM, professions or police listener. `kEM_AttackFinish` sees an operational victim. If the prize is a kEM hunt target, the bail completes the hunt | `PlayerAttacks` skips ownerless targets (`notifications.xml:1503`). Nothing more | None needed |
| **Claim** (spacesuit or marines, ownerless ship) | No listener | `PlayerBoarding` is never signalled in 8.00 scripts; the target is ownerless | None needed |
| **Player's own shots** | Not seen by kEM (no AI attack script). Professions count only a player kill | Warning near a protective station; a kill is reported | Same as vanilla piracy |

## Still open

- **Whose pilot is listed** when the player flies the leader (inference above). One game run with `$debugChance_bounties` on would show it.
- **The real odds of a hunter visit:** that depends on how many NPC pilots kEM has listed when it happens. Measure in game, if it matters.
- **Whether the boost changes the size of the engine's attack penalty.** Log `$relchange` in `PlayerAttacks` and `DistressDroneReportsAttack`.
