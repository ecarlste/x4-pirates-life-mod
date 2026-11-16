# Turret damage landed at 1×

Status: WIP. Measured 2026-11-16 for [#225](https://github.com/ecarlste/x4-pirates-life-mod/issues/225), the 1× recheck of [#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184), [#193](https://github.com/ecarlste/x4-pirates-life-mod/issues/193) and [#196](https://github.com/ecarlste/x4-pirates-life-mod/issues/196). The numbers aren't posted on those tickets yet.

All runs are on X4 8.00 with SWI 0.91 HF1, at 1× (`MarkCombatTest`), with the combat trace on ([testing.md, Game tests](../testing.md#game-tests)).

## The tests

- **`turret_damage_landed_s` and `turret_damage_landed_m`** (new, release tier only): one turret-only wingman on vanilla's Attack order, starting 2 km from a TIE Advanced (8000 hull). The TIE waits and doesn't fight back.
  - Every second the test adds up the target's shield and hull drops, and keeps its shields at 0, so what it measures is hull damage. Under 40% hull, the hull goes back to 100%.
  - Each run lasts 60 s from the first damage. Applied DPS counts from that first second.
  - The loadouts are `apirateslife_test_ywing_turretonly` (the SW4 top turret only) and `apirateslife_test_yt1300_turretsonly` (2 × AG-2G only).
  - The turrets stay in the player's default mode, `defend`, and they fire on the Attack order's target.
- **`capture_wing_turrets_hold` and `capture_wing_turrets_hold_m`** (#184's tests, unchanged apart from the trace).

## Results

### Turret-only damage, 7 runs each

| Turrets | Listed `dps.turrets.all` | Hull damage per second | Share of the listed DPS | Seconds with damage, of 61 | Biggest single second |
| --- | --- | --- | --- | --- | --- |
| Y-wing, SW4 | 1919 | 0.7–5.9 | 0.04–0.3% | 1–9 | 42–84 |
| YT-1300, 2 × AG-2G | 1477 | 174, 363, 395, 586, 595, 779, 1077 | 12–73%, median 40% | 10–35 | 2176–3128 (27–39% of the hull); 6 of 7 runs over 2700 |

- **The SW4 is an ion turret:** 21 hull damage and 540 shield damage per bolt (SWI's `bullet_sw4_s_laser_macro`). Its listed DPS is almost all shield damage, so on hull it does almost nothing. Its shield damage wasn't measured: these tests keep the shields at 0.
- **AG-2G turrets land well under their listed DPS on average,** as #193 suspected, and the rate varies a lot between runs. But their **biggest second is about twice the listed DPS.**
- In the first run, the AG-2G pair's trace landed damage in 20 of the 29 seconds it fired from 0–3° and 600–1400 m. The trace's angle bands are the ship's nose, which says little about turrets that aim on their own.

### #184's turret tests, 5 runs each

| Test | Lowest hull | Turret shots in break / fine / suppress / hold |
| --- | --- | --- |
| Y-wing, 2 × KX7 + SW4 | 67%, 67.9%, 70.25%, 70.25%, 73.5% | 0/0/0/0 in every run |
| YT-1300, KX20 + 2 × AG-2G | 53.8% in every run | 0/0/0/0 in every run |

- **The hold silences turrets: confirmed at 1×.**
- **But these tests never fire a turret.** The prize starts at 80% hull with no shields, already inside the wing's burst margin, so the wing goes straight to the fine stage and the turrets hold from the start. Turret damage in the break isn't tested.
- The YT-1300's 53.8% is one KX20 bolt (2096 hull) from about 80%, the same as #196's comment. The Y-wing's dips come from its KX7s in the fine stage.
- The YT-1300's `dps.lasers.all` without turrets read 2169 in one run, against 1886 in the others. That's unexplained, and it doesn't affect anything above.

## Single-shot damage, from SWI's data

Hull damage per volley on a target with no shields, `value` plus `noshield` times the barrels, from SWI's `bullet_*_macro` files. It assumes every bolt hits.

| Weapon | Per bolt | Barrels | Per volley | TIE/LN (3500) | TIE Advanced (8000) |
| --- | --- | --- | --- | --- | --- |
| SW4, ion (S turret) | 21 | 2 | 42 | 1% | 0.5% |
| AG-2G (M turret) | 136 | 2 | 272 | 8% | 3% |
| H9 single (M turret) | 669 | 1 | 669 | 19% | 8% |
| H9 dual (M turret) | 576 | 2 | 1152 | 33% | 14% |
| H9 quad (M turret) | 474 | 4 | 1896 | 54% | 24% |
| KX20 (M laser), for comparison | 2096 | 1 | 2096 | 60% | 26% |

An H9 quad volley would take a TIE/LN from 80% to about 26%, under the 35% floor. That's #184's KX20 problem again, for #196's one-turret finisher.

## Inferred, not measured: turrets can overshoot the line in the break

The order sets turrets to hold fire only in its 1-second loop (`aiscripts/order.apirateslife.capture.xml`, `$holdturrets`). The margin it holds is `burstseconds` (1.5) of listed DPS, about 2215 for the AG-2G pair. Their biggest second was 2176–3128, so within a second of crossing into the margin they could take the hull roughly 800–900 below the line: about 10% of a TIE Advanced, or about 25% of a TIE/LN. No game test has shown this yet.

## Caveats

- The target sits still and never fights back, so real fights likely land less.
- 7 runs per turret type: enough to see the spread, not to give a rate.

## Open

- A capture-op test with a turret-only YT-1300, on a prize with room for a break (full shields, or a bigger hull), to see whether the overshoot above happens. Its result decides whether #184 is reopened.
- Post the numbers on #184, #193 and #196, and fix any SETA-era numbers in #193's and #196's bodies.
- The SW4's shield damage at 1×, for the wing burst's shield side.
