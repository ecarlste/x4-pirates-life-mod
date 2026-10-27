# Spec: Pirated ships

Plan item: Phase 2, slice 3, Booty v1, "Pirated-ship mark" · Status: Done

## Goal

Every ship that becomes the player's is either **pirated** or a **donation**, so booty can pay the stolen bonus only for real piracy ([DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing)). A ship is pirated if the player took it while the mod was running, by boarding or by its crew bailing, in combat with the player or any ship the player owns. Every other ship is a donation: bought, built, claimed after someone else made it bail, or taken before the mod was installed.

## Context

- Agreed in chat (2026-10-27).
- **Bails:** our bail hook signals `md.APiratesLife_Bail.Bailed` for every bail (`md/apirateslife_bail.xml`). It comes from vanilla's `PlayerOwnedShipAttacks` (`base/md/notifications.xml`), which only runs for player-owned attackers. A bailed ship becomes ownerless, and the player takes it by claiming it (spacesuit or marines).
- **Boarding:** vanilla's `md/boarding.xml` starts a cue per operation on `event_boarding_operation_created` (the operation's `.owner` is the boarding faction, `.boardee` the target). On success, `Transfer_Ownership` (`:2658`) gives the target to that faction with `set_owner`, and also hands over the capturable ships docked at it.
- **Owner changes:** `event_contained_object_changed_true_owner space="player.galaxy" owner="faction.player"` fires for every object that becomes the player's (param = object, param3 = previous true owner), as vanilla's ship counter in `md/notifications.xml:545` uses it.

## Design

**One script, `md/apirateslife_pirated.xml`,** which only marks ships; it changes nothing in the game.

- **Remembering the combat,** in global tables keyed by ship (X4 can't hold variables on a ship, only on NPCs: found in the first game-test run):
  - **A bail** with a player-owned attacker adds the target to `global.$APiratesLife_BailedToPlayer`.
  - **A boarding operation** created by the player adds the boardee to `global.$APiratesLife_BoardedByPlayer`.
- **When a ship becomes the player's,** it's marked pirated if:
  - it was boarded by the player (or was docked at a ship the player boarded: vanilla hands those over in the same boarding); or
  - it was ownerless just before and had bailed to the player.
  Anything else is a donation. Either way the ship leaves the two combat tables, so an old fight can't count for a later change of hands.
- **The mark:** the ship's entry in `global.$APiratesLife_PiratedShips`, `table[$how = 'bail' | 'boarding', $from = <the faction it was taken from>, $time = <player.age>]`. For a bail, `$from` is the owner at the bail, not ownerless (the claim comes after). A later feature asks the library `IsPirated` instead of reading the table, and the `Decided` cue is signalled with `table[$ship, $how]` for every ship that becomes the player's (`$how` null for a donation), for tests and later features. One log line per ship that becomes the player's: `[apirateslife] pirated: …` or `[apirateslife] donation: …`.
- **Not lost:** the mark stays if the ship changes hands again. Booty reads it once, at handover.
- **Ships taken before the mod** aren't in the tables, so they're donations. Nothing scans old saves.
- **Pruned:** whenever a ship becomes the player's, entries for ships that no longer exist (destroyed, sold, handed over) are dropped from all three tables, so they stay small.

## Tasks

- [x] `md/apirateslife_pirated.xml`
- [x] Game tests: bail then claim, boarding, a claim with no bail

## Done when

The scenarios in [`tests/game/features/pirated-ships.feature`](../../tests/game/features/pirated-ships.feature) pass.

## Open questions

- The docked-ship case is tested by hand for now: a game test would need a carrier with a capturable ship docked at it, boarded to the end.
