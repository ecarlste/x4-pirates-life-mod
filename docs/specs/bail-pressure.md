# Spec: Bail pressure

Plan item: SWI build, [#118](https://github.com/ecarlste/x4-pirates-life-mod/issues/118) · Status: Done

## Goal

In a capture operation the target's pilot gets likelier to bail the longer it is held inside the bail gates, so a capture is likely within about 30–35 s for S and 40–50 s for M, the same when only the wing fires. The agreed design is the SWI build spec's [Bail pressure](https://github.com/ecarlste/x4-pirates-life-mod/issues/109) section; this page says how it's built.

## Context

- The numbers: [How 9.x captures feel in numbers, and what matches them under SWI](https://github.com/ecarlste/x4-pirates-life-mod/issues/101) and [Bail pressure under SWI's Enhanced Bailing](https://github.com/ecarlste/x4-pirates-life-mod/issues/96).
- It plugs into the [bail hook](bail-hook.md) and the [capture operation](capture-operation.md).
- The game's bail cue, `PlayerOwnedShipAttacks` (`md/notifications.xml`), also runs on `event_object_signalled` from `player.galaxy` with `param3 = 'shouldwebail'` (param the attacker, param2 the target), which an attacked ship's AI sends (`aiscripts/interrupt.attacked.xml`). A check is evaluated only past the gates and once `$target.pilot.$nextcapturechance` has passed: 30 s after the last check on vanilla, 5 s under SWI.

## Design

- **The gates** are the game's own: shields under 20% or none, hull under 75%, not docked.
- **Time in the gates, not checks.** The operation's state keeps `$gatestime` (time inside the gates so far) and `$gatessince` (when the current stretch began, or null while outside). The operation's 1 s tick updates them; the start sets `$gatessince` if the target is already inside. Pressure is `time / 10 s × CapturePressureStep`. It pauses outside the gates rather than resetting, and nothing resets it on a partial bail.
- **The hook applies it** (`AdjustEjectChance`): `max(chance, min(chance + pressure, CapturePressureCap))`, only for targets with an operation. A fresh operation has no time yet, so its first check is plain.
- **The pressure tick**, in the operation's tick: every `CapturePressureInterval` while `player.occupiedship` is the leader, in the target's sector within 10 km, and the target is inside the gates, it signals `'shouldwebail'` with the leader as attacker. The game then runs its own check, with its own gates, chance and crew batches, through our hook. On vanilla this makes checks every 5 s instead of every 30 s.
- **The tick and the pilot's cooldown** (`$nextcapturechance`): a cooldown longer than the interval (vanilla's 30 s) is cut short; a shorter one (SWI's 5 s after a recent check) is left alone, and the tick waits for it. Clearing every cooldown, as first agreed, let a hit's check and a tick's land 1 s apart, so a fight where the player also fires rolled up to twice as often as a wing-only one. Erik agreed the change in the #118 session.
- **The tick's attacker is the leader**, the ship the player flies, even when only the wing fires. SWI's chance counts the attacker's size and health, so the leader's set those parts of a tick's check. Rejected: naming the wingman nearest the target, whose chance would jump around as wingmen move and take damage. Erik chose the leader in the #118 session.
- **Settings** in `md/apirateslife_config.xml`: `CapturePressureStep` (8), `CapturePressureCap` (80), `CapturePressureInterval` (5). The code falls back to these defaults when a global is missing.
- **Not here:** fear, the pressure left on a pilot after an escape ([#119](https://github.com/ecarlste/x4-pirates-life-mod/issues/119)). The mission readout shows the pressure as the pilot's nerve: see [capture-operation.md](capture-operation.md).

## Done when

Scenarios: [`tests/game/features/bail-pressure.feature`](../../tests/game/features/bail-pressure.feature).

## Open questions

- Gate entry and exit are seen by the 1 s tick, so pressure can be off by up to 0.8 points per transition. Fine for a 30–50 s capture.
