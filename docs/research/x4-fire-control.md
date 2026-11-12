# X4 AI fire control

What an AI script or MD can control about a ship's guns: which weapons fire, for how long, and what it can know about shots in flight. Written for [issue 172](https://github.com/ecarlste/x4-pirates-life-mod/issues/172): the capture order's wingman overshoots the 75% hull hold by the bolts already in flight.

**Status:** WIP: game files mapped, nothing verified in game.

**Sources:**

- X4 8.00 unpack, `/mnt/e/x4-dev/reference/x4-8.00/` (`base/` unless a DLC is named). Paths below are relative to `base/`.
- The 8.00 unpack has no `assets/`, so vanilla weapon macros come from the 9.00 unpack, `/mnt/e/x4-dev/reference/x4-9.00/base/assets/`.
- The SWI weapon comes from SWI 0.91 HF1, `/mnt/e/x4-dev/reference/mods/swi-0.91hf1/`.

**Already known in this repo, not repeated here:**

- How the capture order fires and holds: [`aiscripts/order.apirateslife.capture.xml`](../../aiscripts/order.apirateslife.capture.xml) header comment (lines 2–17) and [capture-operation.md](../specs/capture-operation.md), "Holding fire" and "Rejected or tried".
- Our own `shoot_at` loop never landed a shot in game tests ([capture-operation.md](../specs/capture-operation.md), "Rejected or tried").
- `shoot_at` is only allowed in an AI script's `visible` attention block ([automated-game-testing.md](automated-game-testing.md)).

Labels: **Fact** means the cited file says so. **Inference** means it follows from the files but hasn't been tested.

## 1. Choosing weapons

**Short answer:** yes, by weapon group or by weapon mode. No action fires a single named weapon, but scripts can move single weapons in and out of weapon groups, and `shoot_at` fires only the active groups. Scripts can also set a single weapon's mode, including hold fire. Either works under vanilla's attack script, since it calls plain `shoot_at`.

### Weapon groups (Fact)

- `shoot_at` has `primary` and `secondary` attributes: "Shoot weapons in active primary weapon group. Defaults to true" (`libraries/aiscripts.xsd:2086`, `:2093`). `stop_shooting` has the same pair (`libraries/common.xsd:35590`).
- There are actions to change groups per weapon, and to pick the active group:
  - `add_weapon_to_weapongroup` (`common.xsd:18708`);
  - `remove_weapon_from_weapongroup` (`common.xsd:18728`);
  - `remove_weapon_from_all_weapongroups` (`common.xsd:18748`);
  - `activate_weapongroup` (`common.xsd:18676`);
  - `reset_weapongroups`, which puts lasers back in the first primary group and launchers in the first secondary (`common.xsd:18696`).
- Scripts can read the groups: `primaryweapons.{$weapongroup}.list` (`libraries/scriptproperties.xml:543-546`), `activeweapongroup.primary` (`scriptproperties.xml:800`), and a weapon's `isinactiveweapongroup` (`scriptproperties.xml:1403`).
- The fighter attack script calls `shoot_at` with no `primary`/`secondary` (`aiscripts/fight.attack.object.fighter.xml:339`), so it fires whatever is in the active groups.
- Vanilla's attack order calls `reset_weapongroups` only for ships that are **not** player-owned and have no DPS: "do not reset for player-owned ships since the player might have defined a special weapon group setup" (`aiscripts/order.fight.attack.object.xml:1103-1106`, and the patch at `:396-397`).

**Inference:**

- To fire one laser of four, take the other three out of the active primary group, and leave vanilla's attack script running.
- A player-owned wingman keeps that setup, because the reset above only runs for ships that aren't player-owned.
- Whether `dps.lasers.all` (`scriptproperties.xml:471`) still counts lasers outside any group is not documented. If it drops to 0 for an NPC ship, vanilla would reset the groups.

### Weapon modes (Fact)

- `set_weapon_mode` takes a single `weapon` or a `group` (`common.xsd:35443`). Its values include `weaponmode.holdfire`, "Do not shoot" (`common.xsd:2436`).
- `shoot_at`'s `weaponmode`: "Only weapons/turrets set to the specified mode will shoot at the target(s), defaults to any" (`aiscripts.xsd:2114`).
- `lib.set.weaponmode` sets every **combat** weapon, not just turrets, to a mode (default hold fire), and returns the old modes so they can be restored (`aiscripts/lib.set.weaponmode.xml:18-41`).
- `order.wait`'s `holdfire` parameter uses it (`aiscripts/order.wait.xml:203-206`, restored at `:271-274`), and so does `move.flee` (`aiscripts/move.flee.xml:184-186`).
- A weapon's mode can be read with `.mode` (`scriptproperties.xml:1405`).

**Inference, to check in game:**

- That `holdfire` stops a *fixed forward* gun under `shoot_at`. The schema doesn't say whether `weaponmode.any` (the default) includes hold-fire weapons.
- `order.wait`'s hold fire setting fixed guns too suggests it does.
- Every vanilla use of `set_weapon_mode` in MD is on turrets (for example `md/lib_generic.xml:1781`).

### Other switches (Fact)

- `set_allowed_weapon_systems` allows or disallows whole classes (`laser`, `missile`, `turret_*` …), with `immediate="true"` to "stop firing immediately" rather than "until they lose their current target" (`common.xsd:35210`, enum at `common.xsd:2290`). It can't pick a subset of lasers, and there's no vanilla use in 8.00.
- `fire_turret` takes a turret only (`common.xsd:28054`), with no vanilla use.
- `set_turrets_armed` is for all turrets (`common.xsd:35537`).
- `set_object_active` is a generic activate/deactivate with an animation (`common.xsd:32971`). Nothing says it applies to weapons.
- No `set_component_active` or `set_weapon_active` exists in `common.xsd`, `aiscripts.xsd` or `md.xsd`.

### Does vanilla's attack script fire everything? (Fact)

Yes, everything in the active groups:

- `fight.attack.object.fighter.xml:339` is `shoot_at ... fixedtarget="true"`, with lasers in the default groups, then `stop_shooting missiles="true"`.
- It has no weapon filter.
- Its `disable` parameters are documented as "Nonfunctional in this script since we cannot disable m and s ships" (`fight.attack.object.fighter.xml:28-29`).

## 2. Bounded fire

**Short answer:** no action fires a set number of shots or a set duration.

- `shoot_at` is "Shoot at target when the opportunity arises" (`aiscripts.xsd:2055`): it switches firing on, and the engine fires each gun at its reload rate whenever the target is within tolerance.
- A burst is `shoot_at`, then `wait`, then `stop_shooting`/`cease_fire`.
- The smallest unit a script controls is one script step (about a frame). The smallest unit of fire is one discharge per gun. Counting shots is possible with `event_weapon_fired`.

**Fact:**

- `event_weapon_fired`: "Event for the specified weapon firing (object = the weapon, param = fired bullet/missile/bomb)". It takes an object or a group (`common.xsd:16697`).
- Vanilla uses it in AI-script interrupts:
  - the fighter script ends its attack run when a slow gun fires (`fight.attack.object.fighter.xml:379`, group built from guns with `reloadtime gt 1s` at `:54-62`);
  - the capital script notes "we fired" without interrupting, through `check_value value="false"` (`aiscripts/move.attack.object.capital.xml:885-890`).
- Weapons expose `reloadrate` ("Number of times this weapon fires its default bullet in one second") and `reloadtime` (`scriptproperties.xml:1412-1413`), plus `isreadytofire` (`scriptproperties.xml:1404`).
- Vanilla's in-sector attack loop doesn't budget shots. It fires for the whole attack run, which `move_to` bounds with `interrupt_after_time` (`fight.attack.object.fighter.xml:371-382`), and ends with `cease_fire` (`:487`).
- Vanilla waits as short as 5–15 ms "to ensure we don't have infinite loops" (`fight.attack.object.fighter.xml:648`).
- Some vanilla bullets have a built-in magazine burst:
  - for example `<ammunition value="3" reload="0.7" />` on the Pulse Laser Mk1 bullet (`/mnt/e/x4-dev/reference/x4-9.00/base/assets/fx/weaponFx/macros/bullet_gen_s_laser_01_mk1_macro.xml:7`);
  - the KX7 has none.

**Inference:**

- A one-shot-per-gun burst could work like this: `shoot_at`, then an interrupt on `event_weapon_fired` for the gun group, then `stop_shooting`/`cease_fire`.
- It works if the stop lands before the next discharge: 1/3.6 s ≈ 278 ms for the KX7, a lot longer than a frame.
- It's not verified in game. The #172 probes found that calling `stop_shooting`/`cease_fire` in the damage handler doesn't recall bolts already fired, which is expected. Whether it stops the *next* bolt quickly hasn't been measured.

## 3. Knowing what's in flight

**Short answer:**

- A script learns of a hit through `event_object_hull_damaged` / `event_object_shield_damaged`. Each event carries the damage, so it reads as one event per hit (inference).
- Nothing documents batching or latency.
- No script property gives bullet speed, damage per shot or shots in flight. But `event_weapon_fired` hands the script the bullet itself, and the script can time each bullet from that.

**Fact:**

- `event_object_hull_damaged`: "param = damaged component, param2 = new hull value, param3 = damage" (`common.xsd:12986`). `event_object_shield_damaged` is the same for shields (`common.xsd:12973`).
- `event_object_attacked` gives attacker, kill method and component, but no damage (`common.xsd:12944`). The repo's tests found it fires only now and then ([capture-operation.md](../specs/capture-operation.md), "Holding fire").
- No schema text in `aiscripts.xsd`, `common.xsd` or `md.xsd` describes when AI-script interrupts are delivered. The only timing note is for MD signals: "dispatched in the same frame, but only after the current cue actions are completed" (`md.xsd:4218`).
- `bullet` datatype: only `launcher` (`scriptproperties.xml:861-863`). As a `component`, it inherits `speed`, "Speed relative to the cluster (in m/s)" (`scriptproperties.xml:9`, `:59`), and the component's position and distance properties.
- `weapon` datatype: `maxfirerange`, `isbeam`, `reloadrate`, `reloadtime`, `mode`, `ammo.macro` (`scriptproperties.xml:1398-1414`).
- The `macro` datatype has no bullet speed, lifetime or damage. It has only `explosiondamage.*` for missiles (`scriptproperties.xml:2084-2088`).
- Ship-level values: `dps.lasers.*` (`scriptproperties.xml:468-482`), `maxcombatrange.*` (`:486-514`), and `ismissileincoming` for missiles only (`:612`).
- `get_attackstrength` returns damage per second against a target, split into hull/shield parts, and can be limited to forward weapons (`useforwardweapons`) (`common.xsd:28071`).

**Inference:**

- A script could estimate what's in flight two ways:
  - (a) count `event_weapon_fired` minus damage events;
  - (b) keep each bullet from `event.param` and time it as `distance / bullet.speed`.
- Whether `.speed` and `.distanceto` return useful values on a bullet component is unverified.
- Per-hit damage can be learned from the first `event_object_hull_damaged`'s `param3`, with no need for macro data.
- Without per-bullet tracking, a closed-form estimate is: in flight ≈ guns × `reloadrate` × distance / bullet speed. Speed has to come from a profile or a measurement, since script can't read it from the macro.

## 4. Weapon stats for this case

**Fact:**

- **SWI KX7** (`/mnt/e/x4-dev/reference/mods/swi-0.91hf1/ext/assets/fx/weaponFx/macros/bullet_kx7_s_laser_macro.xml:7-10`):
  - `speed="2800"`, `lifetime="0.84"`: range 2,352 m;
  - `amount="1" barrelamount="1"`;
  - `reload rate="3.6"`;
  - `damage value="160" noshield="100"`;
  - no `ammunition` burst.
- **SWI KX7 weapon** (`.../props/WeaponSystems/standard/macros/weapon_kx7_s_laser_macro.xml:8-9`): `overheat="11000"`, with a heat value of 180 per shot.
- **SWI test X-wing:** four KX7s (`tests/game/apirateslife_tests/libraries/loadouts.xml:17-20`).
- **Vanilla reference, Pulse Laser Mk1** (`/mnt/e/x4-dev/reference/x4-9.00/base/assets/fx/weaponFx/macros/bullet_gen_s_laser_01_mk1_macro.xml:7-11`):
  - `speed="5000"`, `lifetime="0.7"`: range 3,500 m;
  - `reload rate="6"`;
  - `ammunition value="3" reload="0.7"`;
  - `damage value="36"`.

**Inference: in flight at the hold, KX7**

| | Time of flight | Bolts in flight, 4 guns (14.4/s) | Bolts in flight, 1 gun (3.6/s) | #172 probe |
| --- | --- | --- | --- | --- |
| 1 km | 0.36 s | ≈ 5 | ≈ 1.3 | about 7 (4 guns), 1–4 (1 gun) |
| 2 km | 0.71 s | ≈ 10 | ≈ 2.6 | 8–14 (4 guns) |

- The probes are a little above flight time × fire rate. That fits a reaction delay of roughly one or two discharges on top of the flight time.
- So most of the overshoot is physics (bolts already fired), not slow events.
- The probe's "3.25 points" per bolt is presumably a hull-percentage figure for its target; the macro damage is 160.

## 5. Vanilla precedent

**Short answer:**

- Yes: "shoot to disable" in `order.fight.attack.object` (`disable`, `disablehullpercentagethreshold`, default 20), used by boarding.
- It avoids over-killing with a **one-second damage margin**, checked by polling: it stops when the target's hull is no longer more than one second of the attacker's DPS, or when hull% + shield% is at or below the threshold.
- Vanilla doesn't implement it for S/M attackers or S/M targets with fighters.

**Fact:**

- The order's parameters are at `order.fight.attack.object.xml:36-43`. Boarding passes `disable="true"` with the insertion threshold, clamped to 20–80 (`aiscripts/order.fight.board.xml:64`, `:143-144`).
- **Fighters against big targets** (`fight.attack.object.bigtarget.xml`):
  - "if we want to disable the target we will need tighter control of whether we shoot or not" (`:371`);
  - so, each loop pass, it fires only while `$bigtarget.hull gt this.ship.dps.lasers.all and (hullpercentage + shieldpercentage) gt threshold`, and calls `stop_shooting` otherwise (`:396-405`);
  - a pass ends with `wait min="100ms" max="500ms"`, plus the attack-run movement;
  - missiles get the same check with `dps.missiles.all` (`:528`).
- **Turret ships** (`fight.attack.object.medium.xml:1275`, `:1308`; `fight.attack.object.capital.xml:2000`, `:2033`):
  - keep a target only while `hull gt dps.turrets.all * max(scantime, 1s)` and hull% + shield% is above the threshold;
  - an interrupt on `event_object_attacked` re-evaluates targets once below it (`fight.attack.object.medium.xml:1690-1692`, `:1764`).
- **Fighter script:** `disable` is "Nonfunctional in this script since we cannot disable m and s ships" (`fight.attack.object.fighter.xml:28-29`).

**Inference:**

- Vanilla doesn't try for precision. It stops early by a damage margin (one second of DPS) and accepts landing short of the threshold.
- It counts shields in the threshold, and it checks only a few times a second.
- That's close to what our `suppress` phase already does with `$burstseconds` (`aiscripts/order.apirateslife.capture.xml:6-9`).

## What this means for #172's fix options

These are options for Erik to sign off, not decisions.

1. **Short bursts with fewer guns.**
   - **Supported.** Select the guns by weapon group:
     - `remove_weapon_from_weapongroup` / `add_weapon_to_weapongroup`, plus `activate_weapongroup`;
     - `shoot_at` fires only the active groups (`aiscripts.xsd:2086`).
   - Or by weapon mode: `set_weapon_mode weaponmode="weaponmode.holdfire"` on the guns to rest. Whether that holds fixed guns is unverified.
   - Both leave vanilla's attack script (and its aiming) in charge, which matters given that our own `shoot_at` loop never hit.
   - Bursts would be bounded with an `event_weapon_fired` count or a `wait`, then `stop_shooting`/`cease_fire`, and a wait of about one flight time (distance / bullet speed) before the next burst.
   - Restore the groups or modes on every exit: the order's `finish` and the end signal.
   - **Risks:**
     - player-set groups get changed while the order runs;
     - `dps.lasers.*` may drop and change vanilla's choices;
     - nothing here is tested.
2. **Stop early by an estimate of the damage in flight.**
   - **Supported**, and it's vanilla's own method (a one-second DPS margin).
   - The inputs scripts can read: the target's `hull`/`maxhull`, our `dps.lasers.*` or `get_attackstrength`, our distance, gun count and `reloadrate`, and per-hit damage from `event_object_hull_damaged` `param3`.
   - Bullet speed is the one input script can't read from the macro. It has to come from a profile value, or a measurement of `event.param.speed` on `event_weapon_fired`.
   - Fewer guns (option 1) shrinks the margin this needs.
3. **Short bursts with all guns.**
   - **Supported** with the same actions as option 1, without the group changes.
   - With four KX7s, even one discharge per gun is 4 bolts. A burst only helps if the stop lands before the next discharge (278 ms apart) and the next burst waits out the flight time.
   - Expect overshoot of at least one volley per burst, about 4 × 160 hull damage.

## Not found

- No documentation of AI-script interrupt timing: per hit or batched, same frame or next.
- No script property for bullet speed, lifetime, damage per shot, or a count of shots in flight. `bullet.speed` through `event_weapon_fired` is the only route, and it's untested.
- Whether `weaponmode.holdfire` stops fixed (non-turret) guns under `shoot_at`.
- Whether `dps.lasers.*` counts guns that are in no weapon group.
