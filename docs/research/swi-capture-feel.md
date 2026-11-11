# How 9.x captures feel in numbers, and what matches them under SWI

**Status: WIP.** Modelled from the game files and a simulation; nothing run in game yet. Answers [#101](https://github.com/ecarlste/x4-pirates-life-mod/issues/101) on the [SWI build's map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89).

Question: how fast do S/M captures happen in the 9.x build as it is, and what would make the SWI build (X4 8.00 + SWI 0.91 HF1) feel the same under SWI's Enhanced Bailing?

Sources, read only: `V9` = vanilla 9.00 at `E:\x4-dev\reference\x4-9.00\`, `V8` = vanilla 8.00 at `…\x4-8.00\`, `SWI` = SWI 0.91 HF1 `ext02/` (scripts) and `ext/` (ship and shield macros) at `…\mods\swi-0.91hf1\`, this repo's `md/` and `aiscripts/`, and Erik's design session of 2026-10-20/21. Tags: **[read]** = seen in the files or logs; **[inferred]** = reasoning or a model assumption, to check in game.

## What "the 9.x feel" means

What Erik played on 9.00 and liked: the bail hook's flat ×2 (capped at 100) plus ×4 for capture-operation wingmen, vanilla's 30 s cooldown, and capture operations (break to 75% hull, then wingmen only knock shields down). Logged plays from that session:

- An S Discoverer with the player and 3 wingmen bailed on the **2nd check, about 80 s after the hail** (wingman checks 4% → 32% and 6% → 48% after the hook).
- A solo S Falcon bailed on its **first check** at 44% → 88%.
- An M ship fell to 6 wingmen (it needed a re-hail after a false "escaped").

Erik also said he **doesn't like instant bails**: he liked rising pressure "since it makes it less likely to just get an insta bail". So the target is capture times like the ×2/×4 build's, **with fewer bails on the first check**. That's why the agreed bail pressure ([plan](../IMPLEMENTATION_PLAN.md), "Bail pressure in capture operations", not built) starts at the plain chance and rises with time, and why it's time-based: so SWI's 5 s cooldown can't double it.

## Short answer

- **9.x build, time from "inside the gates" to the pilot bailing,** player flying an S ship and firing: S fighter about 10–25 s, M corvette 40–55 s, M miner 50–65 s, M transport 100–130 s; about 20–45 s more when only wingmen fire. **60–75% of S captures end on the first check,** and 25–40% of corvette and miner captures need only one success. This fits the measured S captures of 63–80 s from first shot ([booty.md](booty.md#capture-times)), most of which is breaking the hull and shields.
- **Plain SWI is far slower:** about 6–8 minutes on average for every target, and about a fifth of fights (half of wing-only ones) aren't done after 15 minutes in the gates. SWI checks every 5 s, but NPC morale drops the chance to 0.5–2% per check for most combat ships and 1–6% for civilians.
- **Porting the hook's ×2 as is barely helps** (4–5 minutes), and its integer cast throws away most of SWI's fractional chances.
- **A plain multiplier can't do it:** ×16–24 gets the average close for the player, but wing-only fights stay 2–4× slower, and morale-0 pilots bail on the first check while morale-12 ones drag on.
- **Recommendation: build the agreed bail pressure as designed, on SWI's chance:** start at SWI's plain chance, +8 for every 10 s inside the gates, capped at 80, with the 10 s `'shouldwebail'` tick; drop the hook's ×2 and ×4. Under SWI that gives about **35 s for S and 50 s for M, player-flown or wing-only, with only 1–2% first-check bails.** That's within the 9.x build's range for M, a little slower for S (by design), and it takes no SWI-specific numbers. Details in [Candidates](#candidates).
- **If something is needed before bail pressure is built:** a flat +20 on SWI's chance (one changed line) gets player-flown captures to about 25 s (S) and 50 s (M), but leaves 22% instant bails on S ships and slow wing-only fights.

## How a check works in each build [read]

Both builds run every bail check in vanilla's `PlayerOwnedShipAttacks` cue (`V9 md/notifications.xml` 1184; identical in `V8`, the whole cue diffs empty). SWI's Enhanced Bailing replaces the cue's `do_if[@value='$target.iscapturable']` block (`SWI md/notifications.xml` 45). What stays the same:

- **Triggers:** a hit by a player-owned ship (`event_player_owned_attacked_object`), or a `'shouldwebail'` signal on `player.galaxy`, which the target's AI sends only when its attacker is *not* player-owned (`V9 aiscripts/interrupt.attacked.xml` 280), or a surrender demand. So in a player-led fight, **checks only happen on player-owned hits** unless something else sends `'shouldwebail'`.
- **Gates:** shields below 20% (or no shields), hull below 75%, not docked (`V9` 1250, `SWI` 56).
- **Cooldown per pilot:** the first check is allowed the moment the gates open (`$nextcapturechance` starts at `player.age - 1s`, `V9` 1252); after each evaluated check the next waits a cooldown, unless the pilot bailed.

| | 9.x build (vanilla 9.00 + our hook) | SWI 0.91 HF1 Enhanced Bailing |
| --- | --- | --- |
| Base chance | `46 − combinedskill/5` (34–42 for typical ships), × target/attacker max hull (cap 1), × attacker/target shield+hull % (cap 1), as an integer (`V9` 1263) | `11 + crew + hullshield + size − 1.75 × pilot morale` (`SWI` 72–93): crew = 0–10, rising as crew leaves (`10 − (count+1)/capacity × 10`); hullshield = attacker shield%+hull% ÷ target's, cap 10 (about 2–5 in the gates); size = 0 to 10 by class, 0 for S attacking S or M. At or below 0 it becomes 1 |
| Other factors | ÷4 if the player isn't flying the attacker, ÷2 capital, ÷3 Xenon (`V9` 1265) | ÷2 for S/M combat types: scout, fighter, heavy fighter, interceptor, corvette, bomber, gunboat, scavenger (`SWI` 102–103). No ÷4 for wingmen. A fractional percentage, never rounded |
| Our hook | ×4 for capture-operation wingmen (undoes the ÷4), then ×2, integer, cap 100 (`md/apirateslife_bail.xml`) | none yet |
| Crew out per success | `min(3, max(1, min(capacity × (15 − morale)/15, count)))` (`V9` 1290) | random from `max(20% of capacity, 1)` to `count × 1.2`, capped at count (`SWI` 125–135); 25% chance of everyone if hull is below 10% (140) |
| Pilot bails | when the batch covers all remaining crew, the target isn't a capital ship, and the attacker is player-owned or set to claim | when the batch covers all remaining crew and the target isn't player-owned (`SWI` 157) |
| Cooldown | 30 s (`V9` 1307) | 5 s (`SWI` 170) |

Inputs the model uses:

- **Crew capacity** from the ship macros [read]: vanilla S fighters 0–3 (typically 2), M corvettes 4–9 (typically 6), M miners 7–10, M transporters 12–22 (typically 17). SWI: S fighters almost all 1 (TIE, X-wing), M corvettes 13–56 (CR90 36), M miners 4–18 (Action IV 7, Mando 18), M transporters 4–50 (Gozanti 17, YT-1300 5).
- **Crew aboard** [read]: vanilla NPC crew sets fill 20–75% of capacity (`V9 libraries/people.xml`; pirate sets 80–100%). SWI's sets fill 50–95% (freighters) or 70–90% (military) (`SWI libraries/people.xml`, used by `SWI libraries/ships.xml`). The model draws 20–75% (9.x) and 60–95% (SWI) [inferred: the engine's rounding].
- **Pilot morale** [read]: NPC pilots in both games roll morale 0–12 (`trader_*_random`, `fighter_*_random` in each `libraries/characters.xml`); SWI's rookies 0–6, regulars 2–8 or 7, elites 12. The model draws 0–12 evenly [inferred: the engine's distribution]. Spawned test pilots in Erik's logs had 0, 2, 5, 8, 9, 10, 11, 12.
- **9.x chance:** combinedskill 20–60 gives 34–42 before the hook, 72–76% after [inferred from the capture metrics logs: test pilots 23–56; a Kestrel's logged 38]. Erik's real plays logged lower chances too (32%, 48%, 88%), when the damage ratio or hull ratio was below 1, so the model also runs with 9.x chances drawn from 32–88% ("9.x, logged range" below) [inferred].

## How often checks fire during the suppress phase [read code, inferred timing]

- **Player flying and firing:** every hit is a player-owned hit, so a check comes almost as soon as the cooldown allows. The model assumes a qualifying hit about every 2 s on average.
- **Only wingmen firing:** our capture order (`aiscripts/order.apirateslife.capture.xml`) fires in the suppress phase only while shields are above "1.5 s of the wingman's laser damage + 10%", and stops at that level, so shots in flight take the shields to about 0. A vanilla S wingman with two Pulse Laser Mk1 (36 damage × 6/s each) stops at about 650 shield points, half of an S shield (1196–1380 max, 15 s recharge delay, 50–78/s). So qualifying hits come in **one short window per knock-down**, then nothing while shields regenerate: about 15 s delay plus the regrowth, roughly every 20–40 s. The model uses one window every 20–40 s. SWI S shields look similar (delay 7–18 s, 20–100/s) [read: `SWI ext/assets/props/SurfaceElements/macros/shield_s_*`].
- **What that means:** in 9.x, the 30 s cooldown and the knock-down cycle are about the same length, so wingmen lose little. Under SWI, the 5 s cooldown is wasted on wing-only fights: they still get about one check per knock-down. Unshielded targets are worse: the suppress phase never fires at a target without shields (`$fire` needs `$target.maxshield`), so only the player's hits bring checks.
- **The fix in both lines is the agreed pressure tick:** sending `'shouldwebail'` on a timer makes checks independent of hits. It goes through the same cue, so it works under SWI as is. Under SWI every tick becomes a check (the 5 s cooldown has always passed), so the tick interval sets the check rate.

## Results

`docs/research/swi-capture-feel/sim.py` (run `python3 -I docs/research/swi-capture-feel/sim.py`, about 15 s) simulates 4000 fights per row from the moment the target is inside the gates, with morale 0–12 and the inputs above. Not modelled: the break phase (getting the hull below 75% and shields below 20%), gates closing mid-fight, and hits from anyone but the player's side. Time is in game seconds. "1st-check bail" is the share of fights where the pilot bails on the very first check.

### (a) 9.x build as is

| Target | Attacker | Mean | Median | Done in 60 s | 1st-check bail | Checks | Successes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S fighter (cap 2) | player | 12 s | 2 s | 94% | 75% | 1.3 | 1.0 |
| S fighter (cap 2) | wing only | 31 s | 20 s | 84% | 73% | 1.4 | 1.0 |
| M corvette (cap 6) | player | 38 s | 32 s | 71% | 40% | 2.1 | 1.6 |
| M corvette (cap 6) | wing only | 66 s | 53 s | 57% | 40% | 2.2 | 1.6 |
| M miner (cap 8) | player | 48 s | 34 s | 63% | 27% | 2.4 | 1.8 |
| M miner (cap 8) | wing only | 81 s | 63 s | 47% | 27% | 2.5 | 1.8 |
| M transport (cap 17) | player | 100 s | 96 s | 19% | 1% | 4.0 | 3.0 |
| M transport (cap 17) | wing only | 154 s | 138 s | 10% | 1% | 4.3 | 3.1 |

With the logged range of chances (32–88%), the means are S 23 / 44 s, M corvette 56 / 88 s, M miner 66 / 104 s, M transport 132 / 187 s (player / wing only), with 60% first-check bails on S.

Per check: 76% player-flown, 72% for a wingman (the ÷4 then ×4 loses a little to integer rounding) [read: formula]. M ships need 1–4 successes because vanilla throws out at most 3 crew per success, and high-morale pilots only 1–2.

### (b) Plain SWI, and SWI with the 9.x hook ported as is

| Target | Attacker | Plain SWI: mean / median / not done in 15 min | Hook ×2 as is: mean / median / not done in 15 min |
| --- | --- | --- | --- |
| S fighter (TIE, X-wing; cap 1) | player | 406 s / 271 s / 25% | 296 s / 150 s / 13% |
| S fighter | wing only | 656 s / >15 min / 55% | 558 s / 643 s / 42% |
| M corvette (CR90; cap 36) | player | 465 s / 376 s / 29% | 363 s / 216 s / 20% |
| M corvette | wing only | 758 s / >15 min / 68% | 639 s / 896 s / 50% |
| M miner (Action IV; cap 7) | player | 371 s / 220 s / 21% | 262 s / 115 s / 11% |
| M miner | wing only | 651 s / >15 min / 52% | 518 s / 480 s / 37% |
| M transport (Gozanti; cap 17) | player | 341 s / 197 s / 18% | 240 s / 104 s / 8% |
| M transport | wing only | 628 s / 794 s / 47% | 509 s / 455 s / 34% |
| M transport (YT-1300; cap 5) | player | 384 s / 231 s / 22% | 274 s / 125 s / 11% |

Per-check chance under SWI, S attacker, target at 60% hull and 10% shields:

| Pilot morale | 0 | 3 | 6 | 7 | 9 | 12 |
| --- | --- | --- | --- | --- | --- | --- |
| SWI S fighter (combat, ÷2) | 6.9% | 4.3% | 1.7% | 0.8% | 0.5% | 0.5% |
| Same with the hook's `($Chance * 2)i` | 13% | 8% | 3% | 1% | 1% | 1% |
| SWI miner or transport, crew at 70% (cap 17) | 16.2% | 11.0% | 5.7% | 4.0% | 0.5% | 1.0% |
| 9.x, any target (typical) | 76% | 76% | 76% | 76% | 76% | 76% |

Two things set SWI apart: morale decides almost everything (from morale 7 up, a combat ship sits at the 0.5% floor), and once a check succeeds, SWI's batches are big, so M ships need only about 2 successes whatever their size. That second point means no change to the chance alone can bring back 9.x's spread between a corvette (about 40 s) and a transport (about 100 s): under SWI every M ship takes about the same time.

### Candidates

Mean time in the gates under SWI, player-flown / wing-only, against the 9.x build. "Error" is the average of |SWI − 9.x| ÷ 9.x over the four targets (the S fighter's 12 s makes small gaps count a lot). "1st-check bail" is for the S fighter / the average of the three M targets, player-flown.

| Candidate (on SWI's chance) | S fighter | M corvette | M miner | M transport | Error | 1st-check bail S / M |
| --- | --- | --- | --- | --- | --- | --- |
| *9.x build* | *12 / 31* | *38 / 66* | *48 / 81* | *100 / 154* | | *75% / 23%* |
| *9.x build, logged range* | *23 / 44* | *56 / 88* | *66 / 104* | *132 / 187* | | *60% / 19%* |
| Plain SWI | 406 / 656 | 465 / 758 | 371 / 651 | 341 / 628 | 1307% / 1016% | 2% / 1% |
| ×2, hook as is | 296 / 558 | 363 / 639 | 262 / 518 | 240 / 509 | 934% / 832% | |
| ×8 | 90 / 290 | 116 / 349 | 73 / 251 | 62 / 226 | 232% / 379% | 20% / 10% |
| ×16 | 43 / 170 | 60 / 222 | 37 / 156 | 32 / 142 | 100% / 196% | 39% / 15% |
| ×24 | 27 / 118 | 40 / 167 | 25 / 115 | 23 / 105 | 62% / 127% | 50% / 16% |
| +20 | 26 / 117 | 56 / 248 | 51 / 228 | 50 / 218 | 53% / 193% | 22% / 7% |
| +25 | 21 / 93 | 46 / 201 | 43 / 189 | 42 / 184 | 40% / 139% | 27% / 8% |
| At least 20 (floor) | 29 / 133 | 69 / 294 | 68 / 297 | 69 / 297 | 72% / 258% | 20% / 5% |
| +20 with a 10 s tick | 23 / 33 | 52 / 78 | 47 / 71 | 46 / 68 | 45% / 24% | 22% / 7% |
| +20 with a 5 s tick | 17 / 17 | 38 / 39 | 35 / 36 | 34 / 34 | 33% / 55% | 22% / 7% |
| **Agreed bail pressure** (+8 per 10 s in the gates, cap 80, 10 s tick) | **35 / 39** | **52 / 60** | **49 / 56** | **48 / 57** | **69% / 32%** | **2% / 1%** |
| Bail pressure without the tick | 36 / 69 | 54 / 112 | 51 / 111 | 50 / 111 | 73% / 64% | 2% / 1% |
| Bail pressure at +12 per 10 s, with the tick | 30 / 32 | 44 / 50 | 42 / 47 | 41 / 48 | 57% / 34% | 3% / 1% |
| Bail pressure on ×2 of SWI's chance, with the tick | 32 / 36 | 48 / 55 | 42 / 51 | 42 / 50 | 64% / 34% | 5% / 2% |
| Plain SWI with a 30 s cooldown | 665 / 702 | 767 / 795 | 667 / 709 | 651 / 705 | (much worse) | |
| 9.x chance at SWI's 5 s | 4 / 24 | 15 / 69 | 15 / 72 | 15 / 70 | (too fast) | |
| 9.x chance with a 30 s cooldown | 12 / 28 | 60 / 92 | 61 / 96 | 61 / 94 | 31% / 27% | 75% / 20% |

Reading the table:

- **A multiplier** keeps SWI's morale spread: low-morale pilots bail at once, high-morale ones (most combat pilots) still drag on. ×24 matches player-flown times on average, but half of S captures end on the first check, and wing-only fights stay slow.
- **A longer cooldown** only makes SWI slower; its problem is the chance, not the number of checks.
- **A flat add** gives every pilot a similar base, like 9.x's chance, which hardly depends on morale. +20 brings player-flown M captures within about 15 s of 9.x, but S ships still bail on the first check 22% of the time, and wing-only fights need a tick.
- **9.x's chance with a 30 s cooldown** reproduces the 9.x numbers best, instant bails included, which is what Erik doesn't want. It also needs a second patch inside SWI's block (to push the cooldown back to 30 s) and makes SWI's morale, crew and size terms meaningless.
- **The agreed bail pressure** is the best fit for what Erik asked for. Times land in the 9.x build's range for M targets (about 50 s against 38–132 s), player-flown and wing-only alike; S captures take about 35 s instead of 12–23 s, because the instant bails are gone (2% instead of 60–75%). Its "error" against the 9.x means is higher only because 9.x's S average is built on those instant bails. The ramp also flattens SWI's morale spread: whatever the starting chance, the pressure reaches 40–50% within a minute. The tick matters: without it, wing-only fights take twice as long.
- **Tuning knobs** if it feels slow or fast in game: +12 per 10 s gives about 30 s (S) and 45 s (M); starting from ×2 of SWI's chance changes little (first-check bails 5%).

## Recommendation [inferred]

1. **Build the agreed bail pressure for the SWI build as designed,** applied in `AdjustEjectChance` on SWI's chance: `chance = max(SWI's chance, min(SWI's chance + 8 × whole 10 s periods inside the gates, 80))`, with the 10 s tick expiring `$nextcapturechance` and sending `'shouldwebail'`. No ×2, no ×4, and **no integer cast** (SWI's chances are fractional; the 9.x code's `( … )i` turns 0.5% into 0 before doubling). Keep SWI's 5 s cooldown and its crew batches. Because the step is per 10 s of time, not per check, SWI's 5 s cooldown doesn't double the ramp; it only gives two rolls at each level.
2. Keep the step, cap and interval as config values (as the plan already says), so capture metrics can tune them.
3. **Only if the SWI build has to ship before bail pressure is built:** a flat +20 on SWI's chance, as a config value, in place of the ×2. Player-flown captures are then close to 9.x; wing-only ones take 2–4 minutes.
4. Check in game with capture metrics: per-check chances, checks per minute in the suppress phase, and time from gates to bail, for one S and one M target.

## What ports from the 9.x bail hook to 8.00 + SWI

| Piece | Ports as is? | Notes |
| --- | --- | --- |
| `run_actions AdjustEjectChance` insert before `do_if[@chance='if not $testcheat? then $ejectchance else 100']` | **Yes** [read] | SWI's roll has the same string (`SWI` 108). Our extension must load after SWI (SWI as a dependency in `content.xml`), so the insert lands in SWI's replaced block, not vanilla's |
| `Bailed` signal before `do_if[@value='$eject?']/remove_value[@name='$numcrewbailing']` | **Yes** [read] | SWI keeps both (`SWI` 187, 196). `$pilotbail?` is still set at that point |
| Capture-wing ×4 | **Drop** [read] | SWI has no ÷4, so it would make wingmen 4× better than the player |
| ×2 with `( … )i` and cap 100 | **Change** [read] | Replace with the pressure (or the interim flat add), without the integer cast |
| `$Op.$lastchance` for the readout, `BailChecked` metrics signal | **Yes** [read] | The readout text "last check %s%%" would show a fraction; round it for display only [inferred] |
| `$damageminpercent` = 100 insert (intact on pilot bail) | **Drop** [read] | SWI's block has no `set_value` for it (commented out, `SWI` 160), so the selector would fail with a patch error. SWI already leaves the hull alone |
| `$scuttle` = false insert (no sabotage) | **Drop** [read] | No `$scuttle` in SWI's block; SWI never destroys equipment (the loop is commented out) but still plays the scuttle effect and removes cargo by pilot skill. (Vanilla 8.00 itself does have `$scuttle`; its cue is identical to 9.00's.) |
| Capture readout step 3 (`md/apirateslife_capture.xml` 176–185) | **Adjust** [read] | It reads the pilot's real `$nextcapturechance`, so the wait is right, but the bar's maximum is a hard-coded 30; under SWI it should be 5, or show the pressure instead |

Not part of the hook, but on the same path: SWI destroys unclaimed bailed ships 30–70 minutes after they bail (`SWI` 271–300), and pilot bails no longer need a player-owned or claiming attacker, so NPC fights under SWI leave abandoned ships too [read].

## Open questions, to check in game

- **Fractional chances:** does X4's `chance` attribute use 0.5 as 0.5%, or round it? If it rounds down, SWI's 0.5% floor is 0%, and plain SWI combat pilots with morale 7+ never bail at all. The attribute's type is just "expression" (`V8 libraries/common.xsd` 7121). With the pressure on top it matters little.
- How often `event_player_owned_attacked_object` fires per hit (every hit, or throttled like `event_object_attacked`, which the capture order's tests found fires "only now and then"). The model assumes a qualifying player hit every 2 s.
- The real knock-down cycle with SWI wingmen and SWI shields, and how many qualifying hits land in each window.
- The break phase under SWI: hulls are much bigger (CR90 178,000 vs a vanilla corvette's 8,000–21,000; X-wing 8,500 vs Argon Elite 3,100), so getting to the gates may take longer than the bail phase itself. Not modelled here.
