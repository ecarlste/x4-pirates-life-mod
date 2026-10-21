# Spec: Capture operation

Plan item: Phase 2, slice 1, "Capture operation: wingmen that capture, not kill, started from a comm choice" · Status: Agreed

## Goal

The player picks a capturable ship (not a capital ship) and starts a **capture operation** on it, alone or with their wing. Wingmen stop killing prizes: they break the hull to under 75% (vanilla's bail gate), then only knock shields down, stopping with a margin so shots still in flight land on shields, not hull. The target stays inside vanilla's bail gates. A mission on the HUD shows what's needed for the next bail check, and each outcome ends the operation with its own message. This PR starts operations from a comm choice; a right-click/F menu entry (UI Extensions) and hotkeys (Native Hotkey API) follow as their own PRs and call the same start library.

## Context

- Design: [DESIGN.md, Command modes](../DESIGN.md#command-modes) ("capture, don't kill").
- Agreed in chat (2026-10-20): the three entry points, the PR split, dropping vanilla's ÷4 for wingmen in an op, a 35% floor. On PR #31 Erik moved the hold line to the 75% gate: wingmen stop once the hull is under 75% and the shields are down (the first draft held at 65%). His plasma wingman showed that bolts still in flight wear the hull away, hence the burst margin below.
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
- **The target turns hostile to the player,** like vanilla's "Mark as hostile" (-1 boost, decay 1, 600 s). Starting a capture is the act of piracy, and player-owned ships won't fire on a ship they aren't hostile to: vanilla's own Attack order stands down on a "friendly target". Faction reputation is left to vanilla's cost for the damage done.
  - **Ordering matters:** with wingmen, each capture order applies the boost once it runs. Applied first, the wingmen's escort behavior saw a new enemy and queued vanilla's Attack (missiles and all) ahead of ours.
  - If the op is called off or the target escapes, the boost is reset so the player's escorts don't hunt it down.
- **Operation state:** `global.$APiratesLife_CaptureOps.{$Target} = table[$leader, $members, $op, $lastchance]`, which the bail hook and the order read. A global table, because X4 can't store script variables on a ship (only on NPCs; found by the first game-test run), and AI scripts can read globals.

**Wingman order** (`aiscripts/order.apirateslife.capture.xml`, id `APiratesLife_Capture`, category `internal` so it isn't in the player's order menus):

- **Fights with vanilla's attack script** (`run_script order.fight.attack.object`), and aborts it to hold fire. Vanilla's dogfighting, both in and out of the player's sight.
- **No missiles:** a two-line diff on `fight.attack.object.fighter.xml` skips missile passes (in sight) and missile damage (out of sight) while the pilot carries `$APiratesLife_NoMissiles`. The order sets the flag and clears it when it ends or is cancelled. Without the flag, vanilla is unchanged. In the game tests, torpedoes already in flight one-shot the target from the hold line.
- **Break:** while the target's hull is at or above the hold line (default 75%, vanilla's bail gate), fire at it.
- **Suppress:** below the hold line, fire only at shields. Stop while the target's shields still hold the wingman's **burst**, about 1.5 s of its laser damage (`dps.lasers.all × 1.5`, in hitpoints), so shots still in flight land on shields, not hull. Fire again once shields are 10% (of max) above that.
  - This works for any weapon with no weapon IDs: plasma gets a bigger margin, pulse lasers a small one.
  - A heavily armed wingman may leave shields above the 20% gate; the player or a lighter wingman takes them the rest of the way, and nobody kills the prize.
  - This automates the play-tested ion technique ([spike 1](../research/spike-1-bailing-boarding.md#play-tested-technique-erik)).
- **Floor:** at or below 35% hull, nobody fires.
- **Holding fire:** a handler on the target's hull and shield damage events stops the attack on the damage that crosses a line.
  - `event_object_attacked` only fires now and then, so it isn't used.
  - In the game test the hull stopped at 74.8%, right at the gate.
  - When the op ends, it signals each wingman (`'apirateslife_capture_end'`), which stops even mid-attack.
  - Holding means cease fire, stop turrets (`defencenpc` 'attack' with no target), stop moving (an interrupted attack run otherwise drifts into the prize), and stay within about 2.5 km.
- **Ends** when the target is gone, ownerless, player-owned or the operation is over. Following through gates is left to vanilla's `move.generic`.
- Rejected or tried:
  - Making vanilla's `disable` work for S/M: a big, fragile patch on a core combat script.
  - Our own combat loop (`shoot_at` plus our movement): it never landed a shot in the game tests.
  - Setting the missile ammo aside instead of the flag: vanilla still chose missile passes (it checks for launchers, not ammo), with the lasers off.
  - Better Piracy's attack/chase switch on a 1 s timer: its bug #5.

**Bail checks in an operation** (in `AdjustEjectChance`):

- When the attacker is a member of the target's operation, the player is flying the leader, and the player is in the target's sector, undo vanilla's ÷4 (×4) before our ×2. The wing then presses as hard as the player. Setting `CaptureWingFullChance` (1 = on).
- Integer rounding from vanilla's ÷4 stays (9 ÷ 4 = 2, ×4 = 8); not worth patching vanilla for.
- The hook records the last final chance on the target, for the HUD.

**Operation readout:** a player mission "Capture: <ship>", type fight, abortable. Its one live objective changes with the state:

1. "Knock shields below 20%", with a progress bar.
2. "Damage hull below 75%", with a progress bar.
3. "Hold: next bail check", with a 30 s countdown bar and the last check's chance.

The readout updates every second.

**Outcomes**, each with its own notification and mission ending:

| Outcome | When | Mission |
| --- | --- | --- |
| Abandoned | Target ownerless (pilot bailed) | Completed; "claim it" |
| Captured | Target became player-owned | Completed |
| Destroyed | Target gone | Failed: prize lost |
| Escaped | Leader and wing all more than 15 km away or in another sector | Failed |
| Called off | Player aborts the mission, or the leader is lost | Aborted |

On ending, the target's state is removed and wingmen's orders finish by themselves.

**Comm choice** (`md/conversations.xml` diff plus `md/apirateslife_capture.xml`):

- **The choice:** "Heave to. We're taking your ship." (`g_apirateslife_capture`) is added to the target's comm menu next to vanilla's surrender option, when `Start` would accept the target. Its own cue (`event_conversation_next_section`) starts the op, and the pilot answers with a vanilla refusal line. Vanilla's `SectionHandler` ignores unknown sections.
- **Hostile ships:** vanilla ends the conversation when the ship's faction is hostile to the player, unless surrender is already possible. One patch lets the conversation open when our choice applies, so pirates can work hostile targets such as the Scale Plate Pact. The other options then shown are vanilla's own.
- **Text** lives in our `t/0001-l044.xml`, page 1774100.

**Settings** (`md/apirateslife_config.xml`): `CaptureHoldHull` (75), `CaptureFloorHull` (35), `CaptureWingFullChance` (1).

## Tasks

- [x] `aiscripts/order.apirateslife.capture.xml`: break/suppress/floor with the damage handler; no-missiles patch on `fight.attack.object.fighter.xml`; order icon (`libraries/icons.xml`)
- [x] `md/apirateslife_capture.xml`: `Start`, operation, readout, outcomes, comm handler
- [x] `AdjustEjectChance`: ×4 for operation members; record last chance
- [x] `md/conversations.xml` diff: choice plus hostile allowance; `t/0001-l044.xml`
- [x] Settings in the config and settings scripts
- [x] Game tests (below); validate patches and XML; `make test`
- [x] `make game-test`: all pass
- [ ] Try it in Erik's save (with his plasma wingman)

## Done when

- **Game tests pass:**
  - `capture_wing_full_chance`: the hook gives op members ×4×2, non-members ×2, and members only ×2 when the setting is off; the last chance is recorded.
  - `capture_start_and_destroyed`: `Start` accepts a capturable fighter and refuses a player-owned ship and a second operation; destroying the target ends the op as destroyed.
  - `capture_abandoned`: a forced pilot bail ends the op as abandoned, clears the target's state, and an ownerless ship can't start a new op.
  - `capture_wing_holds_fire`: a real wingman (a fixed pulse-laser loadout from the test extension) breaks a capturable fighter to under 75% and keeps it there for 30 s, with the hull never more than 20 points under the gate (nor below the floor). The target is made uncapturable after the start, so no bail ends the fight.
- **In game:**
  - With 3 S ships, a comm choice on a neutral or SCA fighter starts the op.
  - The wing doesn't kill it, the HUD walks through shields, hull, then bail checks, and the pilot bails.
  - The log shows wing checks with the higher chance.
  - Aborting the mission calls the wing off.

## Open questions

- The burst margin with plasma is untested automatically: vanilla's fighter AI didn't land a plasma bolt on a parked fighter in 180 s. Check with Erik's plasma wingman.
- 1.5 s may be too little or too much for some weapons; tune in play.
- Weapon choice (prefer ion), pressure build-up across failed checks (a nerve meter) and prize crews are left for later.
