# Spec: Capture operation

Plan item: Phase 2, slice 1, "Capture operation: wingmen that capture, not kill, started from a comm choice" · Status: Agreed

## Goal

The player picks a capturable ship (not a capital ship) and starts a **capture operation** on it, alone or with their wing. Wingmen stop killing prizes: they break the hull to a hold line, then only knock shields down so the target stays inside vanilla's bail gates. A mission on the HUD shows what's needed for the next bail check, and each outcome ends the operation with its own message. This PR starts operations from a comm choice; a right-click/F menu entry (UI Extensions) and hotkeys (Native Hotkey API) follow as their own PRs and call the same start library.

## Context

- Design: [DESIGN.md, Command modes](../DESIGN.md#command-modes) ("capture, don't kill").
- Agreed in chat (2026-10-20): the three entry points, the PR split, dropping vanilla's ÷4 for wingmen in an op, hold 65% / floor 35%.
- Bail mechanics: [spike 1](../research/spike-1-bailing-boarding.md#bailing-sm). Gates: shields < 20%, hull < 75%; one evaluated check per target pilot every 30 s (`$target.pilot.$nextcapturechance`); ÷4 when the attacker isn't `player.occupiedship`.
- **Why wingmen currently hurt:** whichever hit lands first after the cooldown uses up the check. A wingman's hit rolls at a quarter of the player's chance, so a wing makes captures slower than flying solo.
- Better Piracy's Harass and its bugs: [prior-art note](../research/prior-art-better-piracy.md). We avoid #5 (helpers kill the prize), #9 (every ending is "completed"), #12 (ends on sector change) and #16 (own bail formula).
- Vanilla pieces used:
  - Vanilla's attack order (`aiscripts/order.fight.attack.object.xml` / `fight.attack.object.fighter.xml`) can't be used for captures. Its `disable` option does nothing for S/M ships (`fight.attack.object.fighter.xml:28`), and it fires missiles from the first pass (`$delaymissiles` starts at 0).
  - The vanilla squad hotkey (`md/orders.xml`, `PlayerSquadAttackPlayerTarget`) stays untouched as the kill command.
  - `md/conversations.xml`, `DefaultComm`: the surrender choice (~line 118) and the hostile check that ends the conversation (~line 36).
  - Missions with objectives and progress bars (`md/boarding.xml` ~line 300) and `event_mission_aborted`.

## Design

**Starting an operation** (`md/apirateslife_capture.xml`, library `Start`, used by every entry point):

- **Eligible targets:** an operational ship with a pilot, `iscapturable`, not a capital ship, not player-owned, not already in an operation. A generic check, with no class or faction IDs (profile pillar).
- **Who takes part:** the leader is `player.occupiedship`, plus its subordinate ships that are in the same sector, operational and undocked. Each wingman gets our internal order, `immediate`; when the order ends, the wingman's default behavior (formation) resumes. A wingman added later doesn't join. That's acceptable for v1, since the player can start a new op.
- **Operation state:** `global.$APiratesLife_CaptureOps.{$Target} = table[$leader, $members, $op, $lastchance]`, which the bail hook and the order read. A global table, because X4 can't store script variables on a ship (only on NPCs; found by the first game-test run), and AI scripts can read globals.

**Wingman order** (`aiscripts/order.apirateslife.capture.xml`, id `APiratesLife_Capture`, category `internal` so it isn't in the player's order menus):

- **Its own small combat loop, lasers only:** `shoot_at` (missiles off) plus vanilla's combat flight behaviour (`select_flight_behaviour`; attack runs, and `gaindistance` inside 700 m). It re-decides about twice a second.
  - Why not vanilla's attack script: in the first game-test run, a missile already in flight killed the target from 74% hull within a second of the first hit. Aborting the script can't recall missiles.
  - `shoot_at` needs `visible` attention, so out of the player's sight wingmen only follow the target and hold fire.
- **Break:** while the target's hull is above the hold line (default 65%, inside the 75% gate with margin), fire at it. The player chose the target, so relations aren't checked.
- **Suppress:** at or below the hold line, fire only while the target's shields are above 5%, and stop once they're down. Fire again when they regenerate to 10%. Shields stay under the 20% gate while the hull barely moves. This automates the play-tested ion technique ([spike 1](../research/spike-1-bailing-boarding.md#play-tested-technique-erik)).
- **Floor:** at or below 35% hull, nobody fires.
- **Holding fire:** an interrupt handler on every hit on the target stops shooting on the hit that crosses a line, so overshoot is one burst at most (about 10% hull in the game test). When the op ends, it signals each wingman (`'apirateslife_capture_end'`), which stops even mid-attack. Holding means cease fire, stop turrets (`defencenpc` 'attack' with no target), and stay within about 2.5 km.
- **Ends** when the target is gone, ownerless, player-owned or the operation is over. Following through gates is left to vanilla's `move.generic`.
- Rejected:
  - Patching vanilla's fighter attack script to respect `disable`: a big, fragile patch on a core combat script.
  - Wrapping vanilla's attack script and aborting it at the lines: missiles in flight kill the prize anyway.
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

**Settings** (`md/apirateslife_config.xml`): `CaptureHoldHull` (65), `CaptureFloorHull` (35), `CaptureWingFullChance` (1).

## Tasks

- [x] `aiscripts/order.apirateslife.capture.xml`: break/suppress/floor with the hit handler
- [x] `md/apirateslife_capture.xml`: `Start`, operation, readout, outcomes, comm handler
- [x] `AdjustEjectChance`: ×4 for operation members; record last chance
- [x] `md/conversations.xml` diff: choice plus hostile allowance; `t/0001-l044.xml`
- [x] Settings in the config and settings scripts
- [x] Game tests (below); validate patches and XML; `make test`
- [ ] Deploy with `make deploy-local`, run `make game-test`, try it in Erik's save

## Done when

- **Game tests pass:**
  - `capture_wing_full_chance`: the hook gives op members ×4×2, non-members ×2, and members only ×2 when the setting is off; the last chance is recorded.
  - `capture_start_and_destroyed`: `Start` accepts a capturable fighter and refuses a player-owned ship and a second operation; destroying the target ends the op as destroyed.
  - `capture_abandoned`: a forced pilot bail ends the op as abandoned, clears the target's state, and an ownerless ship can't start a new op.
  - `capture_wing_holds_fire`: a real wingman breaks a capturable fighter to the hold line and keeps it there for 30 s without taking it below the floor. The target is made uncapturable after the start, so no bail ends the fight.
- **In game:**
  - With 3 S ships, a comm choice on a neutral or SCA fighter starts the op.
  - The wing doesn't kill it, the HUD walks through shields, hull, then bail checks, and the pilot bails.
  - The log shows wing checks with the higher chance.
  - Aborting the mission calls the wing off.

## Open questions

- How the simple combat loop looks next to vanilla's dogfighting (no evasion, no boost): check in game with 3 ships.
- Out of the player's sight wingmen don't fire (no out-of-sight damage simulation). Fine while the player leads up close; Raid Sector will need it.
- Weapon choice (prefer ion), pressure build-up across failed checks (a nerve meter) and prize crews are left for later.
