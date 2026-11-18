# Spec: Capture operation

Plan item: Phase 2, slice 1, "Capture operation: wingmen that capture, not kill, started from a comm choice" · Status: Done

## Goal

The player picks a capturable ship (not a capital ship) and starts a **capture operation** on it, alone or with their wing. Wingmen stop killing prizes: they break the hull to under 75% (vanilla's bail gate), then only knock shields down, stopping with a margin so shots still in flight land on shields, not hull. The target stays inside vanilla's bail gates. A mission on the HUD shows the bail gates, the pilot's nerve and the crew aboard, and each outcome ends the operation with its own message. This PR starts operations from a comm choice; a right-click/F menu entry (UI Extensions) and hotkeys (Native Hotkey API) follow as their own PRs and call the same start library.

## Context

- Design: [DESIGN.md, Command modes](../DESIGN.md#command-modes) ("capture, don't kill").
- Agreed in chat (2026-10-20): the three entry points, the PR split, dropping vanilla's ÷4 for wingmen in an op, a 35% floor. On PR #31 Erik moved the hold line to the 75% gate: wingmen stop once the hull is under 75% and the shields are down (the first draft held at 65%). A game-test wingman that happened to roll plasma cannons showed that bolts still in flight wear the hull away, hence the burst margin below.
- Bail mechanics: [spike 1](../research/spike-1-bailing-boarding.md#bailing-sm). Gates: shields < 20%, hull < 75%; one evaluated check per target pilot every 30 s (`$target.pilot.$nextcapturechance`); ÷4 when the attacker isn't `player.occupiedship`.
- **Why wingmen currently hurt:** whichever hit lands first after the cooldown uses up the check. A wingman's hit rolls at a quarter of the player's chance, so a wing makes captures slower than flying solo.
- Better Piracy's Harass and its bugs: [prior-art note](../research/prior-art-better-piracy.md). We avoid #5 (helpers kill the prize), #9 (every ending is "completed"), #12 (ends on sector change) and #16 (own bail formula).
- Vanilla pieces used:
  - Vanilla's attack script (`aiscripts/order.fight.attack.object.xml` / `fight.attack.object.fighter.xml`) does the fighting. Its own `disable` option does nothing for S/M ships (`fight.attack.object.fighter.xml:28`), and it fires missiles from the first pass (`$delaymissiles` starts at 0).
  - Vanilla's "Mark as hostile" interaction (`ui/addons/ego_detailmonitor/menu_userquestion.lua`): a -1 relation boost from one ship toward the player, which is what lets player-owned ships attack a neutral.
  - The vanilla squad hotkey (`md/orders.xml`, `PlayerSquadAttackPlayerTarget`) stays untouched as the kill command.
  - `md/conversations.xml`, `DefaultComm`: the surrender choice (~line 118) and the hostile check that ends the conversation (~line 36).
  - Missions with objectives and progress bars (`md/boarding.xml` ~line 300) and `event_mission_aborted`.

## Design

**Starting an operation** (`md/apirateslife_capture.xml`, library `Start`, used by every entry point):

- **Eligible targets:** an operational ship with a pilot, `iscapturable`, not a capital ship, not player-owned, not already in an operation. A generic check, with no class or faction IDs (profile pillar).
- **Who takes part:** the leader is `player.occupiedship`, plus its subordinate ships that are in the same sector, operational and undocked. Their other orders are cancelled, as vanilla's squad commands do, so a queued Attack can't kill the prize later. Each wingman gets our internal order, `immediate`; when the order ends, the wingman's default behavior (formation) resumes. A wingman added later doesn't join. That's acceptable for v1, since the player can start a new op.
- **The target turns hostile to the player,** like vanilla's "Mark as hostile" (-1 boost, decay 1, 600 s, reason `relationchangereason.markedashostile`), so it reads the same in logs and to anything that reads boost reasons. 8.00's `common.xsd` doesn't list that reason, but the game accepts it. Vanilla's police and relation chain then applies unchanged. Starting a capture is the act of piracy, and player-owned ships won't fire on a ship they aren't hostile to: vanilla's own Attack order stands down on a "friendly target". Faction reputation is left to vanilla's cost for the damage done.
  - **Ordering matters:** with wingmen, each capture order applies the boost once it runs. Applied first, the wingmen's escort behavior saw a new enemy and queued vanilla's Attack (missiles and all) ahead of ours.
  - If the op is called off or the target escapes, the boost is reset so the player's escorts don't hunt it down.
- **Operation state:** `global.$APiratesLife_CaptureOps.{$Target} = table[$leader, $members, $op, $lastchance, $gatestime, $gatessince]` (the last two for [bail pressure](bail-pressure.md)), which the bail hook and the order read. A global table, because X4 can't store script variables on a ship (only on NPCs; found by the first game-test run), and AI scripts can read globals.

**Wingman order** (`aiscripts/order.apirateslife.capture.xml`, id `APiratesLife_Capture`, category `internal` so it isn't in the player's order menus):

- **Fights with vanilla's attack script** (`run_script order.fight.attack.object`), and aborts it to hold fire. Vanilla's dogfighting, both in and out of the player's sight. The finisher (below) flies its own passes instead.
- **No missiles:** a diff on `fight.attack.object.fighter.xml` stops missiles and torpedoes while the pilot carries `$APiratesLife_NoMissiles`. The order sets the flag and clears it when it ends or is cancelled. Without the flag, vanilla is unchanged. In the game tests, torpedoes already in flight one-shot the target from the hold line.
  - *In sight:* the missile-pass condition gets `and not @this.$APiratesLife_NoMissiles`, so no missile pass is chosen.
  - *Out of sight:* 8.00 has no missile gate. `get_attackstrength` picks the missiles, and the script then spends them and applies their damage. Right after each of its two calls (the attacker's own, and each formation follower's that joins in), the patch empties the spent and impacting ammo and zeroes the missile results, so no missile spends ammo, deals damage or draws a countermeasure.
- **Groups** ([#296](https://github.com/ecarlste/x4-pirates-life-mod/issues/296)): who fires is set by three groups the operation picks (`Groups`) and the target's shields and hull. The break and suppress stages, the wing's burst and its margin went: a six-ship wing's 1.5 s burst was bigger than a G9 Rigger's shields plus its hull above the line, so the operation opened with the finisher alone, which couldn't outpace the shields' regen.
  - **When:** at the start of the op, and again whenever a wingman is destroyed or leaves the op (order cancelled, docked, out of the sector), or the finisher changes. Otherwise they stay fixed. Ships are taken in order: the finisher first, then the rest, closest to the target first.
  - **The finisher:** the closest wingman with a forward gun (`dps.lasers.all` above 0), picked about once a second and kept while it still runs the order and has one. A wingman with turrets only never is one (common in SWI's M class: the CR90, Crusader, Gozanti and customs corvette have no fixed weapon slots).
  - **Shield breakers:** the smallest group whose summed `dps.lasers.all + dps.turrets.all`, on paper, takes full shields to 0 in 2 s; the whole wing if it can't. G9 Rigger: two R41s. Turrets count since [#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184); `dps.all` would add missiles, which the order blocks. Each order keeps its ship's figures on the pilot (`$APiratesLife_Dps`, and `$APiratesLife_GunDps`, one forward gun's: `dps.lasers.all` over its operational forward guns), taken while none of its guns or turrets are held back.
  - **Hull breakers:** taken from the shield breakers in the same order, while their summed 1.5 s of DPS stays at most 20% of max hull, so their overshoot leaves the hull at 55% or more. The finisher is always in. G9: the finisher alone.
  - **Band breakers:** the finisher, then the next shield breakers with a forward gun, while their summed one-gun 0.6 s bursts stay at most 10% of max shields. That sum is the **band stop**. G9: two R41s, about 1.2k, 9%.
  - The 2 s and the 20% are global overrides with defaults (`$APiratesLife_CaptureShieldSeconds`, `$APiratesLife_CaptureHullShare`), not in the config file.
  - **No group:** a ship in no group firing now holds fire, turrets on hold, and stays close with the evasive hold (below).
- **Break:** while the target's hull is at or above the hold line (default 75%, vanilla's bail gate):
  - **Shields up:** the shield breakers fire, down to 0. Each stops on the hit that takes the shields to 0, and comes back once they regrow past 10% (`shieldresume`). One already firing on them carries on down to 0.
  - **Shields down** (or regrowing, under 10%): the hull breakers fire. Each stops on the hit that takes the hull under 75%: that's the one hull hit the wing makes.
  - **How they fire:** vanilla's attack with turrets. A hull breaker in a group of more than one doesn't stop at 0 shields: its attack carries on into the hull. When the finisher is the only ship in the group firing now (the G9's hull breakers, any one-ship wing), it flies its **pass** instead: every forward gun while the shields are up, two (`finishguns`) once they're down, going back to every gun if they regrow, so only those guns' bolts in flight overshoot, about a bolt each. With one gun it landed a hit on about one pass in two, and a pass came every 15 to 25 s, so about 1 run in 100 didn't hold under 75% in time ([#182](https://github.com/ecarlste/x4-pirates-life-mod/issues/182)).
  - A ship on its pass fires only within 600 m (`finishrange`) of the target: in free flight one fixed gun fired through whole attack runs out to 5 km and rarely landed from far out, so about 3 runs in 100 never held under 75% in time. Further out it holds fire and flies straight at the target, rechecking every second, and its pass starts again once it's in range. A shot fired out of range ends the pass, and so does flying more than 100 m past the range, checked every second. The 100 m of slack keeps a finisher at the line from flipping between the two. The hold's evasive moves aren't used for this, as they keep a wingman where it is.
  - **The finisher's pass** (`aiscripts/apirateslife.capture.pass.xml`, [#205](https://github.com/ecarlste/x4-pirates-life-mod/issues/205)): a nose-on run at the target with `shoot_at`, breaking off inside 100 m, then on past the target, without firing, towards a point 600 m beyond it, until it's 400 m away; then the next pass. Vanilla's attack runs carried the finisher 1 to 3 km out between passes, one short pass in range every 15 to 20 s ([#182](https://github.com/ecarlste/x4-pirates-life-mod/issues/182)), and against a TIE/LN at full shields it stalled: the shields regrew between passes, and 8 runs in 10 didn't get the hull under 75% in 30 s. With its own pass, about 1 run in 6 (7 of 41) still doesn't within 60 s against a still target: a pass lands about 1 s of fire, and the 6 to 10 s turn can outlast the shields' recharge delay. Flying out further (exit 1.2 km) made every pass fire but each cycle longer, and was no better. The trim to `finishguns` on the hit that takes the shields to nothing, and the restore when they regrow, cut the pass short; the next starts from where the finisher is, still on its run-in, so the trace showed no lost fire.
  - A fixed gun can miss for good when the nose is locked on the target's centre. After 10 s (`missseconds`) of firing within range with no hit on the target, a ship on its pass swaps the longest-kept of its guns for one it took out, taking each in turn, and the window starts again. The group never holds more than `finishguns` guns there (one in [#172](https://github.com/ecarlste/x4-pirates-life-mod/issues/172), two since [#182](https://github.com/ecarlste/x4-pirates-life-mod/issues/182)).
- **Band:** below the hold line, the band breakers keep the shields in a band always under the 20% bail gate (`shieldgate`), with no hull damage. A ratchet toward the 35% floor would end the capture: at the floor nobody fires, the shields regrow and the pressure stops.
  - They fly the pass with **one gun** each, stop at the band stop, and come back at the band stop plus 10% of max shields. G9: 9% to 19%. The band stop is the sum of their one-gun bursts, so their shots in flight land on shields. Once firing, a ship keeps on down to the stop from pass to pass: it rechecks after each one, and checking against the resume point there held it whenever a pass ended between the two.
  - This works for any weapon with no weapon IDs: heavy, slow guns get a bigger burst, pulse lasers a small one.
  - A wing with no finisher (turrets only) has no band breakers, and the player knocks the shields down.
  - **Small shields** ([#205](https://github.com/ecarlste/x4-pirates-life-mod/issues/205)): when even the finisher's one-gun burst is over 10% of max shields (a TIE/LN's 900 against an X-wing), the finisher alone fires, on its pass with two guns, down to the 20% gate from 30%. Across 40 runs of the test below, from 70% hull, the lowest was 46%, with no kill and no breach of the floor.
    - Not the whole wing: every wingman with every gun firing down to the gate started from 2 km, and the bolts in flight after the stop took a TIE/LN from 70% to 21% hull in about a second. Firing only within 600 m didn't help: vanilla's attack often didn't fire in range, so the shields regrew, and a four-gun burst from 400 m still went from 51% to 24%.
    - The finisher's two guns don't always keep up with the recharge, as on its passes above the line: about 1 run in 5 doesn't knock the shields down twice in 120 s.
  - This automates the play-tested ion technique ([spike 1](../research/spike-1-bailing-boarding.md#play-tested-technique-erik)).
- **Floor:** at or below 35% hull, nobody fires.
- **Wingmen's turrets** ([#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184)): they fire as the player set them only for a ship firing with vanilla's attack while the hull is at or above 75%. Otherwise (on its pass, holding, in the band or at the floor) each wingman sets its turrets to hold fire (`set_weapon_mode` holdfire), saving each one's own mode, and puts them back once it fires with vanilla's attack again or the order ends, is cancelled or loses the prize. Left alone, the turrets fired at full rate from 2 km while the finisher closed in, and took the hull to 63% on their own. A wingman whose turrets hold and who has no forward gun doesn't fire at all, as vanilla's attack fails the order with no DPS.
  - **Setting** `CaptureWingmenTurrets`: 1 (the default) as above, 0 leaves them to the player throughout. Wingmen only; the player's own ship gets its own setting ([#197](https://github.com/ecarlste/x4-pirates-life-mod/issues/197)).
- **Success bar** (agreed with Erik on [#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184), 2026-11-13): each wing setup captures, holding the prize between the gate and the floor, in at least 90% of attempts. A setup outmatched by its target may fall short: one X-wing bails a full-health TIE Phantom in about 80% of runs within 300 s (32 of 40, from a 2 km start at 1×), as the finisher keeps it inside the bail gates for only about 25 s of the 300, and that's fine, as one fighter needn't beat every target; the player watches how the wing fares against bigger shields and adjusts it (Erik on [#272](https://github.com/ecarlste/x4-pirates-life-mod/issues/272), 2026-11-17). The 35% floor and never killing the prize are the current intent, not a hard rule for the long term. One heavy bolt can overshoot far: a KX20 bolt is 2096 hull, 26% of a TIE Advanced's, so a YT-1300 finisher takes it from 80% to about 54% in one hit.
- **Holding fire:** a handler on the target's hull and shield damage events stops the attack on the damage that crosses a line.
  - `event_object_attacked` only fires now and then, so it isn't used.
  - In the game test the hull stopped at 74.8%, right at the gate.
  - When the op ends, it signals each wingman (`'apirateslife_capture_end'`), which stops even mid-attack.
  - Holding means cease fire, stop the defence officer's attack (`defencenpc` 'attack' with no target; the turrets are already on hold fire, above), stop the attack run (an interrupted one otherwise drifts into the prize), and stay within about 1.5 km, inside laser range (from 2.5 km, a game test's prize recharged its shields from 34% to 90% while the wingman flew back in). Within that, the wingman keeps flying short evasive moves (vanilla's evasive flight behaviours, as `move.evade` uses them, 3 s at a time so it can fire again soon): in Erik's game a wingman that sat still while holding was shot down.
- **Ends** when the target is gone, ownerless, player-owned or the operation is over. Following through gates is left to vanilla's `move.generic`.
- Rejected or tried:
  - Making vanilla's `disable` work for S/M: a big, fragile patch on a core combat script.
  - Our own combat loop for the whole wing (`shoot_at` plus our movement): an early version never landed a shot in the game tests. The finisher's pass (above), a later one in its own script, does.
  - Setting the missile ammo aside instead of the flag: vanilla still chose missile passes (it checks for launchers, not ammo), with the lasers off.
  - Better Piracy's attack/chase switch on a 1 s timer: its bug #5.

**Bail checks in an operation** (in `AdjustEjectChance`):

- **SWI build:** no wing bonus ([#117](https://github.com/ecarlste/x4-pirates-life-mod/issues/117)). SWI's Enhanced Bailing has no ÷4 for wingmen, so the ×4 (and its `CaptureWingFullChance` setting) went, with the hook's ×2. On the 9.x line, a member's check got ×4 before our ×2 while the player flew the leader in the target's sector.
- **Bail pressure** raises the chance the longer the target is held inside the gates, and a pressure tick asks for checks every 5 s: see [bail-pressure.md](bail-pressure.md).
- The hook saves each check's final chance in the operation's state (`$lastchance`), and the mission readout shows it, rounded for display only: "Pilot's nerve: last check N%".

**Operation readout** ([#120](https://github.com/ecarlste/x4-pirates-life-mod/issues/120)): a player mission "Capture: <ship>", type fight, abortable. Its one live objective changes with the state:

1. **The bail gates:** "Knock shields below 20%", then "Damage hull below 75%", each with a progress bar.
2. **"Pilot's nerve":** inside the gates (docked counts as outside, as for pressure), a bar of `CapturePressureCap` that empties as bail pressure builds toward the cap. Fear from an earlier operation counts too, so a shaken pilot starts with less nerve. After the first check it reads "Pilot's nerve: last check N%".
3. **"Crew aboard n/max":** once crew start to leave, the crew still aboard out of those aboard at the start, as a bar, with the last check's chance. Only ships with crew besides the pilot get this step, in the briefing too. Erik chose "after the first crew bail" in the #120 session, since the mission shows one bar at a time.

Nothing in it assumes a cooldown length, so it reads the same with SWI's 5 s and vanilla's 30 s. The readout updates every second, only on change.

**Outcomes**, each with its own notification and mission ending:

| Outcome | When | Mission |
| --- | --- | --- |
| Abandoned | Target ownerless (pilot bailed) | Completed; "claim it" |
| Captured | Target became player-owned | Completed |
| Destroyed | Target gone | Failed: prize lost |
| Escaped | Leader and wing all more than 15 km away or in another sector for 30 s, counted only once someone has been within 15 km; or nobody gets that close within 5 minutes of the start | Failed |
| Called off | Player aborts the mission, or the leader is lost | Aborted |

On ending, the target's state is removed and wingmen's orders finish by themselves.

**Comm choice** (`md/conversations.xml` diff plus `md/apirateslife_capture.xml`):

- **The choice:** "Heave to. We're taking your ship." (`g_apirateslife_capture`) is added to the target's comm menu next to vanilla's surrender option, when `Start` would accept the target. Its own cue (`event_conversation_next_section`) starts the op, and the pilot answers with a vanilla refusal line.
- **Quiet in vanilla's handler:** vanilla's `SectionHandler` logs "ERROR: Unexpected section" for any `g_` section it doesn't know, so the patch names ours in its chain, just before that catch-all (found in Erik's save).
- **Hostile ships:** vanilla ends the conversation when the ship's faction is hostile to the player, unless surrender is already possible. One patch lets the conversation open when our choice applies, so pirates can work hostile targets such as the Scale Plate Pact. The other options then shown are vanilla's own.
- **Text** lives in our `t/0001-l044.xml`, page 1774100.

**Settings** (`md/apirateslife_config.xml`): `CaptureHoldHull` (75), `CaptureFloorHull` (35), `CaptureWingmenTurrets` (1).

## Tasks

- [x] `aiscripts/order.apirateslife.capture.xml`: break/band/floor with the damage handler; no-missiles patch on `fight.attack.object.fighter.xml`; order icon (`libraries/icons.xml`)
- [x] `md/apirateslife_capture.xml`: `Start`, operation, readout, outcomes, comm handler
- [x] `AdjustEjectChance`: record last chance (the ×4 for operation members left with the SWI build)
- [x] `md/conversations.xml` diff: choice plus hostile allowance; `t/0001-l044.xml`
- [x] Settings in the config and settings scripts
- [x] Game tests (below); validate patches and XML; `make test`
- [x] `make game-test`: all pass
- [x] Try it in Erik's save: S captures with 3 wingmen and solo at the same time, then an M (6 crew) with 6 wingmen (2026-10-21). Found the early "escaped" and the comm-section error, fixed in the follow-up PR

## Done when

Scenarios: [`tests/game/features/capture-operation.feature`](../../tests/game/features/capture-operation.feature).

- **Game tests pass.** Since [#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184) the wing tests fail only on what must hold in every run (no kill, no hull below the floor, and their own rules below) and report the lowest hull, as how far a run overshoots the gate varies with the weapons. The 90% bar is checked with repeated batches before a release ([testing.md](../testing.md#game-tests)).
  - `capture_start_and_destroyed`: `Start` accepts a capturable fighter and refuses a player-owned ship and a second operation; destroying the target ends the op as destroyed.
  - `capture_abandoned`: a forced pilot bail ends the op as abandoned, clears the target's state, and an ownerless ship can't start a new op.
  - `capture_escaped`: a target warped 25 km away from an engaged operation ends it as escaped after 30 s.
  - `capture_escape_waits_for_engagement`: an operation started 20 km away is still running 40 s later.
  - `capture_marked_as_hostile`: the boost from an operation without wingmen, and from a wingman's order, carries the same reason as vanilla's "Mark as hostile", made by the test extension's Lua with the call vanilla's menu makes.
  - `capture_comm_choice`: in an SWI game, opening vanilla's default comm with a capturable fighter's pilot and picking the choice through the engine functions the dialog menu uses starts an operation.
  - `capture_abort_calls_wing_off`: in an SWI game, aborting the mission with the engine call the mission menus make ends the op as called off, and the wingman drops the capture order for its default one.
  - `capture_readout`: on a crewed Gauntlet 12 km away (beyond the pressure tick), the mission, read as the mission menus read it, walks through shields, hull (step 1 of 3), the nerve bar at about 72 of 80 after 10 s in the gates (step 2), and "Crew aboard n/max" with the last check's chance after a forced one-crew bail (step 3). A crewless fighter's mission has only 2 steps.
  - Neither the comm nor the abort test clicks a menu, so a manual scenario covers SWI's own comm and mission menus.
  - `capture_wing_holds_fire`: a real wingman (a fixed pulse-laser loadout from the test extension) breaks a capturable fighter (80% hull, shields held down until then) to under 75% and keeps it there for 30 s, never below the floor, and the wingman never still (under 10 m/s) for 5 s in a row. The target is made uncapturable after the start, so no bail ends the fight.
  - `capture_wing_holds_fire_three_wingmen`: three such wingmen, starting 2 km from the target, 120° apart and facing it, pilots at skill 15, so every run starts the same way. The same checks but no movement check ([#172](https://github.com/ecarlste/x4-pirates-life-mod/issues/172)), and only one wingman (the finisher) fires until the hull is under 75%: with no shields, the hull breakers fire, and the finisher alone fits them.
  - `capture_wing_turrets_hold` and `capture_wing_turrets_hold_m`: the hull checks of `capture_wing_holds_fire` (no movement check) from the same 2 km start, with one turreted wingman, a Y-wing (two KX7s and an SW4 top turret) and a YT-1300 (one KX20 and two AG-2G turrets). No turret fires more than 1 s after the wing leaves the break, and once the order is cancelled each turret is back in the mode it started in. They report the shots by stage and the ship's DPS with and without its turrets. The YT-1300 has one forward slot, and with its turrets on hold its one KX20 lands about one hit per 100 s, so its test reports a run that never holds 30 s under 75% within 180 s instead of failing it (a turret finisher is [#196](https://github.com/ecarlste/x4-pirates-life-mod/issues/196)).
  - `capture_wing_turrets_break_m` (release tier only): a turret-only YT-1300 (two AG-2G turrets), 2 km from a TIE Advanced at full hull and shields, not held down, so its turrets fire through the break. With no forward gun it's never the finisher, and it breaks the hull only as a hull breaker, whose overshoot leaves 55% or more. It fails on the hull under 55% (75% while it isn't a hull breaker), a kill, the floor, a turret shot more than 1 s after it stops firing with vanilla's attack, or a turret not back in its mode. Over 120 s it reports how many times it stopped and the lowest hull, how far the bolts in flight took the target once its turrets held ([#225](https://github.com/ecarlste/x4-pirates-life-mod/issues/225), [#241](https://github.com/ecarlste/x4-pirates-life-mod/issues/241)).
  - `capture_wing_knocks_shields_again`: one X-wing, 2 km from a TIE/LN at 70% hull (inside the hold line) with full shields, not held down. The wing must knock the shields under 20% twice (down, back over 20%, down again) within 120 s. It fails on a kill, the floor, or 20 s in a row at full shields with no shot from the wing in that time (holding fire, the bug). A wing that's firing but missing is reported, not failed: 20 s at full shields with shots, or the 120 s timeout with a shot in its last 20 s. The rate is under small shields in the band above ([#205](https://github.com/ecarlste/x4-pirates-life-mod/issues/205)).
  - `capture_wing_breaks_full_shields`: one X-wing, 2 km from a full-health TIE/LN with its shields not held down, so the finisher, alone in every group, fights from full shields on its own passes. It fails on a kill or the floor, and reports the time, the lowest hull, the knock-downs and the longest stretch at full shields. A run that doesn't get the hull under 75% within 60 s is reported, not failed, at the rate given under the finisher's pass above ([#205](https://github.com/ecarlste/x4-pirates-life-mod/issues/205)).
  - `capture_wing_bails_phantom` (release tier): one X-wing, 2 km from a full-health TIE Phantom (about 5600 shields) with nothing forcing the bail, through the whole operation. It fails on a kill or the floor, and reports whether the pilot bailed within 300 s, 32 of 40 at 1× from that 2 km start ([#272](https://github.com/ecarlste/x4-pirates-life-mod/issues/272)), against an 80% bar (6 of 10 in the release tier); a timeout is reported, not failed ([#216](https://github.com/ecarlste/x4-pirates-life-mod/issues/216)).
  - `capture_wing_breaks_freighter`: four R41s and two HWK-290s, fitted as in Erik's save, 2 km from a full-health G9 Rigger that reacts as its own AI would, without the player ([#296](https://github.com/ecarlste/x4-pirates-life-mod/issues/296)). It fails unless the G9 is inside both bail gates within 180 s, and on a kill or the floor. Before the groups, the finisher fired alone from the start and the G9 was still at full hull and shields after 180 s. A 40-run proof needs at least 36 passes.
  - `no_missiles_in_sight` and `no_missiles_out_of_sight`: a flagged torpedo X-wing and an unflagged one each attack a TIE Advanced held at 50% hull, 1-6 km from the player and 150 km away. Within 60 s the unflagged wingman fires a missile, as vanilla does, and the flagged one fires none.
- **In game:**
  - With 3 S ships, a comm choice on a neutral or SCA fighter starts the op.
  - The wing doesn't kill it, the HUD walks through shields, hull, then the pilot's nerve, and the pilot bails.
  - The log shows wing checks with the higher chance.

## Open questions

- The groups' 2 s, 1.5 s and 0.6 s, and the 20% and 10% shares, may be too little or too much for some weapons; tune in play.
- Weapon choice (prefer ion), pressure build-up across failed checks (a nerve meter) and prize crews are left for later.
