# Turret damage landed at 1×

Status: done. Measured 2026-11-16 for [#225](https://github.com/ecarlste/x4-pirates-life-mod/issues/225), the 1× recheck of [#184](https://github.com/ecarlste/x4-pirates-life-mod/issues/184), [#193](https://github.com/ecarlste/x4-pirates-life-mod/issues/193) and [#196](https://github.com/ecarlste/x4-pirates-life-mod/issues/196). The numbers are posted on those tickets; the overshoot found here is [#241](https://github.com/ecarlste/x4-pirates-life-mod/issues/241).

All runs are on X4 8.00 with SWI 0.91 HF1, at 1× (`MarkCombatTest`), with the combat trace on ([testing.md, Game tests](../testing.md#game-tests)).

## The tests

- **`turret_damage_landed_s` and `turret_damage_landed_m`** (new, release tier only): one turret-only wingman on vanilla's Attack order, starting 2 km from a TIE Advanced (8000 hull). The TIE waits and doesn't fight back.
  - Every second the test adds up the target's shield and hull drops, and keeps its shields at 0, so what it measures is hull damage. Under 40% hull, the hull goes back to 100%.
  - Each run lasts 60 s from the first damage. Applied DPS counts from that first second.
  - The loadouts are `apirateslife_test_ywing_turretonly` (the SW4 top turret only) and `apirateslife_test_yt1300_turretsonly` (2 × AG-2G only).
  - The turrets stay in the player's default mode, `defend`, and they fire on the Attack order's target.
- **`capture_wing_turrets_hold` and `capture_wing_turrets_hold_m`** (#184's tests, unchanged apart from the trace).
- **`capture_wing_turrets_break_m`** (release tier only): a capture op with one turret-only YT-1300 (2 × AG-2G), 2 km from a TIE Advanced at full hull and shields, not held down, so the turrets fire through the break. It fails on the hull under 75% (a turret-only wing never finishes), a turret shot more than 1 s after the break, a kill or the floor, and reports how far past the line (the margin under the wing's burst, 2215) the turrets took the target. It runs 120 s; the shields regrow while it holds, so it can cross the line more than once.

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

## Turrets overshoot the line in the break: 3 runs of 4 failed

`capture_wing_turrets_break_m`, 4 runs:

| Run | Result | Lowest hull | Furthest past the line | Late turret shots | Left the break |
| --- | --- | --- | --- | --- | --- |
| 1 | pass | 100% | never reached it | 0 | 0 times |
| 2 | fail | 68.8% | 2712 (34% of the hull) | 8 | 2 times |
| 3 | fail | 92.5% | 1087 (14%) | 72 | 2 times |
| 4 | fail | 62.8% | 3189 (40%) | 0 | 2 times |

- **Run 1:** that TIE Advanced had 8733 shields (run 2's about 4364; the loadout varies), and the two AG-2Gs never outpaced their regrowth.
- **Run 2:** on the first crossing the turrets went 951 past the line before the order held them, as the order's 1 s loop predicted. While they held, the shields regrew past the burst and the order released them, as designed. On the second crossing the wingman was 250–500 m out, nearly every bolt hit, and the turrets fired for about 1.5 s before the order held them again: 924 shields and about 1760 hull, from 90.8% to 68.8%.
- **Run 3:** the order released the turrets at 79 s and never held them again: the margin was inside the burst from 114 s, and the turrets kept firing until the run ended at about 121 s. The order logged nothing in that time, so while the wingman is firing, the turret check doesn't run every second as assumed. Why: see below.
- **Run 4:** under 75% with no shot more than 1 s late, so even the 1 s the test allows lets the turrets through the gate at close range.
- **So a turret-only wing breaks the gate on its own,** which the spec says it doesn't ([capture-operation.md](../specs/capture-operation.md), the finisher). None went under #184's 55% bar or the 35% floor, in 4 runs.

## After #241's fix: 10 runs of 10 passed

**Why run 3's hold never came back:** the order sets the turrets only in its `decide` pass, and while the attack script runs, only the hit handler brings it back there, once the margin is inside `$wingburst`. On the pass that released the turrets, `$wingburst` was worked out before the release, with the turrets still counted as held: 0 for a turret-only wing. So the handler never stopped it above 75%, and the turrets were never held again. Under 75% the suppress check stopped it on the first hit, as the shields were already down. That's likely runs 2 and 4 too: both big overshoots came on the second crossing, after a release, and run 4's turrets stopped at the gate with no late shot. The fix: while its turrets fire, the handler stops a wingman at the full burst, where `decide` holds them.

| Run | Lowest hull | Furthest past the line | Left the break |
| --- | --- | --- | --- |
| 1, 3, 5, 7, 9 | 100% | never reached it | 0 times |
| 2 | 93.3% | 752 | 6 times |
| 4 | 84.5% | 1458 | 3 times |
| 6 | 93.4% | 743 | 3 times |
| 8 | 94.4% | 663 | 2 times |
| 10 | 93.6% | 730 | 4 times |

- Every crossing stopped inside the 2215 margin, the turrets now holding on the hit itself, not after up to 1 s, and the wing cycled between the break and the hold through the 120 s.
- Only half the runs test the line: the first run of each batch of 2 never reached it. Run 1's TIE Advanced had 8733 shields, which the AG-2G pair never outpaces, as in the first batch's run 1 above. Why it's always the first run of a session isn't known.

## Caveats

- The target sits still and never fights back, so real fights likely land less.
- 7 runs per turret type: enough to see the spread, not to give a rate.

## Open

- The SW4's shield damage at 1×, for the wing burst's shield side.
