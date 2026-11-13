# Spec: Bail pressure

Plan item: SWI build, [#118](https://github.com/ecarlste/x4-pirates-life-mod/issues/118) and fear, [#119](https://github.com/ecarlste/x4-pirates-life-mod/issues/119) · Status: Done

## Goal

In a capture operation the target's pilot gets likelier to bail the longer it is held inside the bail gates, so a capture is likely within about 30–35 s for S and 40–50 s for M, the same when only the wing fires. The agreed design is the SWI build spec's [Bail pressure](https://github.com/ecarlste/x4-pirates-life-mod/issues/109) section; this page says how it's built.

## Context

- The numbers: [How 9.x captures feel in numbers, and what matches them under SWI](https://github.com/ecarlste/x4-pirates-life-mod/issues/101) and [Bail pressure under SWI's Enhanced Bailing](https://github.com/ecarlste/x4-pirates-life-mod/issues/96).
- It plugs into the [bail hook](bail-hook.md) and the [capture operation](capture-operation.md).
- The game's bail cue, `PlayerOwnedShipAttacks` (`md/notifications.xml`), also runs on `event_object_signalled` from `player.galaxy` with `param3 = 'shouldwebail'` (param the attacker, param2 the target), which an attacked ship's AI sends (`aiscripts/interrupt.attacked.xml`). A check is evaluated only past the gates and once `$target.pilot.$nextcapturechance` has passed: 30 s after the last check on vanilla, 5 s under SWI.

## Design

- **The gates** are the game's own: shields under 20% or none, hull under 75%, not docked.
- **Time in the gates, not checks.** The operation's state keeps `$gatestime` (time inside the gates so far) and `$gatessince` (when the current stretch began, or null while outside). The operation's 1 s tick updates them; the start sets `$gatessince` if the target is already inside. Pressure is `time / 10 s × CapturePressureStep`. It pauses outside the gates rather than resetting, and nothing resets it on a partial bail.
- **The hook applies it** (`AdjustEjectChance`): `max(chance, min(chance + pressure, CapturePressureCap))`, only for targets with an operation. A fresh operation has no time yet, so its first check is plain, unless its pilot has fear (below).
- **The pressure tick**, in the operation's tick: every `CapturePressureInterval` while `player.occupiedship` is the leader, in the target's sector within 10 km, and the target is inside the gates, it signals `'shouldwebail'` with the leader as attacker. The game then runs its own check, with its own gates, chance and crew batches, through our hook. On vanilla this makes checks every 5 s instead of every 30 s.
- **The tick and the pilot's cooldown** (`$nextcapturechance`): a cooldown longer than the interval (vanilla's 30 s) is cut short; a shorter one (SWI's 5 s after a recent check) is left alone, and the tick waits for it. Clearing every cooldown, as first agreed, let a hit's check and a tick's land 1 s apart, so a fight where the player also fires rolled up to twice as often as a wing-only one. Erik agreed the change in the #118 session.
  - "Shorter" has 1 s of slack (`PressureTickCheck`): in the frame of SWI's check, its `player.age + 5s` can read back as a hair over 5 s, which the tick took for a long cooldown and rolled again ([#173](https://github.com/ecarlste/x4-pirates-life-mod/issues/173)).
- **The tick's attacker is the leader**, the ship the player flies, even when only the wing fires. SWI's chance counts the attacker's size and health, so the leader's set those parts of a tick's check. Rejected: naming the wingman nearest the target, whose chance would jump around as wingmen move and take damage. Erik chose the leader in the #118 session.
- **Fear** ([#119](https://github.com/ecarlste/x4-pirates-life-mod/issues/119)): when an operation is called off or its target escapes, `End` reads the pressure left (before the operation's state goes) and stores it on the target's pilot, an NPC, as `$APiratesLife_Fear = table[$points, $time]`. The name has no SWI in it, so the 9.x line can keep it.
  - **Decay when read:** the `Fear` library returns `points × CaptureFearDecayFactor ^ (seconds since / CaptureFearDecayInterval)`, a smooth curve rather than steps: 40 points read as 28.3 after 150 s and 20 after 300 s at the defaults. No timer runs. Erik chose smooth over halving every 300 s in the #119 session: no cliff for players to time a return against.
  - **A new operation starts from it:** the operation's start reads the pilot's fear into the state's `$fear` and takes it off the pilot; `Pressure` adds it to the time-based part. So the first check of an operation on a shaken pilot isn't plain. Fear doesn't decay while an operation runs, and `End` stamps what's left with the time it ended (agreed in the #119 session).
  - **Cleared:** a capture (the ship becomes the player's, or the pilot bails) or the ship's destruction leaves no fear, because the operation already took it off the pilot and puts nothing back.
  - Fear isn't capped: a long hold can leave more than `CapturePressureCap`, which then lasts longer before the chance drops below the cap. The cap still applies to the chance. Agreed in the #119 session.
- **Settings** in `md/apirateslife_config.xml`: `CapturePressureStep` (8), `CapturePressureCap` (80), `CapturePressureInterval` (5), `CaptureFearDecayFactor` (0.5), `CaptureFearDecayInterval` (300). The code falls back to these defaults when a global is missing. A factor of 0 or less, or an interval of 0 or less, means no fear; a factor above 1 counts as 1 (no decay).
- **The mission readout** shows the pressure, fear included, as the pilot's nerve: see [capture-operation.md](capture-operation.md).

## Done when

Scenarios: [`tests/game/features/bail-pressure.feature`](../../tests/game/features/bail-pressure.feature).

## Open questions

- Gate entry and exit are seen by the 1 s tick, so pressure can be off by up to 0.8 points per transition. Fine for a 30–50 s capture.
