# Shields on SWI S ships

Status: Done for SWI 0.91 HF1, read from the unpacked files on 2026-11-15. The loadout rule and the three shieldless ships aren't verified in game ([Assumptions to verify in game](#assumptions-to-verify-in-game)).

What shields every S-size ship in Star Wars Interworlds carries when an NPC faction spawns it: slots, which generators fit, totals, recharge and delay, and the spread across all S ships.

**Why:** [#216](https://github.com/ecarlste/x4-pirates-life-mod/issues/216) needed capture-test targets that represent S ships' shields. It chose the TIE/LN (low), the TIE Phantom (median) and the TIE Reaper (high, reported only); see [Statistics](#statistics-66-ships-with-a-resolvable-shield-fit).

Paths use `SWI_UNPACKED` (the unpacked SWI 0.91 HF1), `X4_UNPACKED` (the unpacked 8.00 `base\`, DLC folders next to it) and the unpacked 9.00 files, as [environment.md, Paths](../environment.md#paths-eriks-machine) names them.

## Sanity check against in-game measurements: both match, no multiplier

- **TIE/x1 (`tie_advanced_macro`)**: hull 8000. It has 3 slots tagged `small shield unhittable`. The game test spawns it with `<level exact="1.0"/>` as galempire ([`apirateslife_tests.xml`](../../tests/game/apirateslife_tests/md/apirateslife_tests.xml), its `tie_advanced_macro` targets). The best S shield galempire owns is `shield_s_novaldex60` (2911 HP), and 3 × 2911 = **8733**, which matches the measurement.
- **TIE/LN (`tie_fighter_macro`)**: hull 3500. It has 1 slot tagged `tie1 shield unhittable`. The only tie1 shield galempire owns is `shield_s_auxtie` (900 HP), so the total is **900**, which matches.
- Total shields = the sum of `recharge max` over the fitted generators. No ship-level multiplier exists.
- The level-1.0 loadout skipped `shield_s_zr41`, which is bigger (3557) and fits the slot, but whose ware is owned only by newrepublic/rebelalliance. That backs up the model used below: **NPC-generated loadouts pick only shields whose ware `<owner>` includes the spawning faction**, and level 1.0 picks the best of them.

## How shields are determined (method)

1. **Slots** are connections in the ship *component* whose tags include `shield`:
   - most ships: `small shield unhittable`
   - TIE/LN family and droids: `tie1 shield unhittable`
   - fighters with droid sockets: a second tag set, `astromech shield` or `astromechhead shield`
   - vanilla Xenon/Kha'ak: `small shield standard`
2. **A shield fits** when its component's connection tags (minus `component`) are a subset of the slot's tags:
   - `shield_s_*` (component `shield_s_inv_standard`): `shield small`
   - auxtie and quintadint: `shield tie1`
   - astromechs: `shield astromech`
   - r2astrohead: `shield astromechhead`
   - gnkastro: `shield gonk`, which no S ship slot accepts
3. **Buyable/spawnable:** SWI's `<SWI_UNPACKED>/ext02/libraries/wares.xml` removes every vanilla shield ware (arg/tel/par/spl/ter/bor, racer). What's left for S ships is the 19 SWI `shield_s_*` wares, plus vanilla `shield_kha_s_standard_01_mk1` and `shield_xen_s_standard_01_mk1/mk2`. SWI diff-patches the two Xenon shields to 2050 and 3000 HP.
4. **No per-ship default loadouts for NPCs:**
   - SWI's `loadouts.xml` only adds gamestart loadouts (for example `sw_xwing_mc80start`).
   - `loadoutrules.xml` only touches deployables and units.
   - Only the vanilla Kha'ak/Xenon patches, the `*_menu_macro` showcase ships, the Yorik-et and `ship_xen_s_fighter_l` carry a `<loadouts>` block in the macro.
   - So for nearly every ship, the shields are **ambiguous by loadout level**. The table gives:
     - the level-1.0 fit: the best faction-owned shield per slot, which is what the game tests spawn
     - the level-0 fit: the worst faction-owned shield per slot
     - the any-shield range, ignoring ownership
   - Faction ownership uses the union of the ship ware's owners. A specific spawning faction can narrow it.
5. **Recharge** is the sum of the per-generator `rate` values. **Delay** is per generator (if a fit mixes generators, all distinct delays are listed). Every shield macro has `hull integrated="1"`: there are no destructible shield generators on S ships.

## Unusual things to know for capture tuning

- **Astromech shields have `delay="0"`.** The `shield_s_r2astro`, `r1astro`, `r4astro`, `q7astro`, `s19astro` and `r2astrohead` macros regenerate (25-40 HP/s) **even while being hit**, with no recharge delay. Every X-wing, Y-wing, ARC-170, Delta-7, Eta-2, N-1, V-wing and Miy'til carries one. That is a small but constant drain on a wing trying to hold shields under 20%.
- **TIE/LN-family and droid fighters are a separate class** (`tie1` slot, 450-900 HP total, 25-30 HP/s, 10-14 s delay). Their shields are only 8-26% of hull.
- **Big "S" ships out-shield many M ships:**
  - The Razor Crest, TIE Reaper and U-wing (6/6/5 slots) reach 16-18k shields.
  - The TIE Fury and TIE Defender carry shields of 1.4-1.6x their hull.
- **Three ships probably spawn with no shields** (unverified; worth a look in-game). Slot tags and owners leave no valid shield:
  - **Yorik-et (`yv_fighter_macro`, owner khaak, hull 25000):**
    - Its macro loadout names `shield_kha_s_standard_01_mk1_macro`, tagged `shield small standard`, but its SWI component slot is `small shield unhittable`, so the shield doesn't fit.
    - No khaak-owned shield fits.
  - **`ship_xen_s_fighter_l_macro` (Xenon, hull 16000):** same problem. Its macro loadout names 3× Xenon mk2 (`standard` tag) on `unhittable` slots.
  - **TIE Silencer:** its ship ware owner is `ownerless`, and it appears in no shipgroup. If someone buys it and generates a loadout, it gets that faction's shields: 10105-17785 with any shield, 14555 with galempire's best.
  - These three are left out of the statistics.
- **`ship_xen_s_fighter_02_a_macro`:** its macro loadout fits 2× Xenon mk2 on `con_shield_01` and `con_shield_02`, but its vanilla component (9.00 files) has only `con_shield_01`. Expect 3000, not 6000.
- **`firespray_macro` sits in `<SWI_UNPACKED>/ext/assets/units/size_s/macros/` but is `class="ship_m"`** (hull 42000, 10 slots). It is excluded.

## Skipped macros (19 of 88 files in `size_s/macros`)

- **Not `ship_s`:** `firespray_macro` and `firespray_menu_macro` (ship_m).
- **Start-menu/showcase variants**, not in any shipgroup, job or ware: `bwing_menu`, `ewing_menu`, `fang_menu`, `hwk_290_01_menu`, `razorcrest_menu`, `rz1awing_menu`, `ship_mando_s_n1_menu`, `t65b_xwing_01_menu`, `ywing_btla4_menu`.
  - Several of these fit tabsx shields in their macro loadout, for example a B-wing menu ship at 4×2749 = 10996.
- **Drones and deployables:**
  - `imp_probe_droid_macro`: no shield slot
  - `ship_gen_s_fightingdrone_01_a_macro`: vanilla defence drone
  - `ship_gen_s_lasertower_01_a_macro`: no shield slot
- **Unused or orphaned:**
  - `n1pi_macro`: its component `n1pi` is neither indexed nor present
  - `vulture_droid_f_macro`: no ware, no group
  - `ship_kha_s_fighter_01/02_a_macro`: 745 HP, not referenced by SWI
  - `ship_xen_s_scout_01_a_macro`: 2050 HP, not referenced
- **Kept** even though no shipgroup uses them, because each has a ware (buyable): `t70_xwing_orange_macro` and `tie_silencer_macro`.

## Statistics (66 ships with a resolvable shield fit)

| Measure | Min | Q1 | Median | Mean | Q3 | Max |
|---|---|---|---|---|---|---|
| Max shields, level-1.0 fit | 450 | 3018 | **5835** | 6662 | 8733 | 17785 |
| Max shields, level-0 fit | 450 | 2021 | 4167 | 4564 | 6063 | 12126 |
| Recharge HP/s, level-1.0 fit | 20 | 60 | **110** | 144 | 180 | 600 |
| Recharge HP/s, level-0 fit | 25 | 35 | 95 | 89 | 105 | 210 |
| Hull | 2200 | | 8500 | 10858 | | 35000 |

**Ships for each statistic (level-1.0 fit):**

- **Lowest shields, 450 HP:** the droids (Vulture droid, Tri-Droid, Hyena; quintadint, 25 HP/s, 14 s delay).
  - The lowest TIE is the TIE/LN family at 900. The TIE/LN is the measured one.
- **Median shields, 5835 HP:**
  - **TIE Phantom** and **TIE Shuttle**, both 5822 (2× novaldex60, 110 HP/s, 7.5 s delay)
  - Y-wing BTL-BP, 5848
  - T-70 orange and Y-wing BTL-BPM, 5740
  - ARC-170 and Y-wing BTL-B, 5948
- **Highest shields:**
  - **U-wing UT-60D**, 17785 (5× zr41, only 100 HP/s)
  - TIE Reaper, 17466
  - Razor Crest, 16170
- **Recharge rate:**
  - **Median, 110 HP/s:** TIE Phantom / TIE Shuttle again. Next closest: Fang and N-1 Modified (100), and Miy'til (120).
  - **Minimum, 20 HP/s:** A-wing (1× zr41).
  - **Maximum, 600 HP/s:** Razor Crest (6× cec1077, but 18 s delay).
- **A clean min/median/max test trio among Imperial ships** (a single owner and a single shield type, so easy to spawn as galempire at level 1.0):
  - TIE/LN: 900 HP, 30/s, 10 s
  - TIE Phantom: 5822, 110/s, 7.5 s
  - TIE Reaper: 17466, 330/s, 7.5 s
  - The TIE/x1 (8733) sits at Q3.

## S shield generators available in SWI (from `<SWI_UNPACKED>/ext/assets/props/SurfaceElements/macros/`)

| Shield macro | Fits | Max HP | Rate HP/s | Delay s | Ware owners |
|---|---|---|---|---|---|
| shield_s_zr41 | small | 3557 | 20 | 10 | newrepublic, rebelalliance |
| shield_s_quintadq4 | small | 3018 | 60 | 9 | commerceguild |
| shield_s_novaldex60 | small | 2911 | 55 | 7.5 | galempire, sienar, ascendancy, sith |
| shield_s_tabsx | small | 2749 | 70 | 8 | corporate, anoat |
| shield_s_cec1077 | small | 2695 | 100 | 18 | most factions (not valarian) |
| shield_s_novaldex45 | small | 2426 | 45 | 10 | kuat, hoersh, rendili, galempire, ascendancy, sith, sienar |
| shield_s_quintadq2 | small | 2318 | 60 | 12 | all SW factions |
| shield_s_z9 | small | 2318 | 65 | 8 | newrepublic, rebelalliance |
| shield_s_novaldex40 | small | 2291 | 40 | 8 | all SW factions |
| shield_s_p12 | small | 2021 | 35 | 7 | all SW factions |
| shield_s_auxtie | tie1 | 900 | 30 | 10 | corporate, kamino, kuat, incom, galempire, ascendancy, sith, sienar, miningguild |
| shield_s_quintadint | tie1 | 450 | 25 | 14 | commerceguild, hoersh |
| shield_s_r2astro | astromech | 450 | 25 | 0 | newrepublic, rebelalliance, corporate, kamino, naboo |
| shield_s_r2astrohead | astromechhead | 450 | 25 | 0 | newrepublic, rebelalliance, corporate, kamino, kuat, naboo, moncal |
| shield_s_q7astro | astromech | 350 | 20 | 0 | all SW factions |
| shield_s_r4astro | astromech | 300 | 25 | 0 | all SW factions |
| shield_s_r1astro | astromech | 250 | 30 | 0 | corporate, anoat |
| shield_s_s19astro | astromech | 100 | 40 | 0 | commerceguild |
| shield_s_gnkastro | gonk | 3000 | 40 | 0 | all SW factions (no S slot takes it) |
| shield_xen_s_standard_01_mk2 (SWI diff) | small standard | 3000 | 160 | 2 | xenon |
| shield_xen_s_standard_01_mk1 (SWI diff) | small standard | 2050 | 100 | 3 | xenon |
| shield_kha_s_standard_01_mk1 (vanilla) | small standard | 745 | 40 | 4 | khaak |

Note that `shield_s_*` (tags `shield small`) also fits vanilla `small shield standard` slots. So Xenon/Kha'ak ships *could* take SWI shields, but their factions don't own those wares.

## Per-ship table (sorted by level-1.0 max shields)

"Level-1.0 fit" is the best faction-owned shield per slot. "Level-0" is the worst faction-owned shield per slot. "Any-shield range" ignores ownership.

| # | Macro | Name | Owners (ship ware) | Hull | Slots | Level-1.0 fit (faction max) | Shields max | Recharge HP/s | Delay s | Level-0 fit total | Rate | Any-shield range |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `tie_silencer_macro` | TIE Silencer | ownerless | 12000 | 5 | (none fits) | 0 | 0 | - | 0 | 0 | 10105-17785 |
| 2 | `ship_xen_s_fighter_l_macro` | Unknown Ship | xenon | 16000 | 3 | (none fits) | 0 | 0 | - | 0 | 0 | 6063-10671 |
| 3 | `yv_fighter_macro` | Yorik-et | khaak | 25000 | 1 | (none fits) | 0 | 0 | - | 0 | 0 | 2021-3557 |
| 4 | `vulture_droid_macro` | Vulture-class droid | commerceguild, hoersh | 2200 | 1 | s_quintadint | 450 | 25 | 14 | 450 | 25 | 450-900 |
| 5 | `tri_droid_macro` | Tri-Droid Fighter | commerceguild | 3500 | 1 | s_quintadint | 450 | 25 | 14 | 450 | 25 | 450-900 |
| 6 | `hyena_macro` | Hyena-class droid | commerceguild, hoersh | 4500 | 1 | s_quintadint | 450 | 25 | 14 | 450 | 25 | 450-900 |
| 7 | `tie_fighter_mg_macro` | TIE Fighter Mining Guild | miningguild | 3400 | 1 | s_auxtie | 900 | 30 | 10 | 900 | 30 | 450-900 |
| 8 | `tie_fighter_macro` | TIE Fighter | ascendancy, galempire, kuat, sienar | 3500 | 1 | s_auxtie | 900 | 30 | 10 | 900 | 30 | 450-900 |
| 9 | `tie_interceptor_macro` | TIE Interceptor | ascendancy, galempire, kuat, sienar | 5500 | 1 | s_auxtie | 900 | 30 | 10 | 900 | 30 | 450-900 |
| 10 | `tie_bomber_macro` | TIE Bomber | ascendancy, galempire, kuat, sienar | 8500 | 1 | s_auxtie | 900 | 30 | 10 | 900 | 30 | 450-900 |
| 11 | `tie_brute_macro` | TIE Brute | galempire | 11000 | 1 | s_auxtie | 900 | 30 | 10 | 900 | 30 | 450-900 |
| 12 | `eta2_actis_yellow_macro` | Eta-2 Actis-class Interceptor | corporate, kamino | 4100 | 2 | s_auxtie+s_r2astro | 1350 | 55 | 0/10 | 1150 | 60 | 550-1350 |
| 13 | `fang_macro` | Fang Fighter | mandodw, mandoraiders, valarian | 4250 | 1 | s_cec1077 | 2695 | 100 | 18 | 2021 | 35 | 2021-3557 |
| 14 | `ship_mando_s_n1_macro` | N-1 Modified Starfighter | bountyhunters | 4650 | 1 | s_cec1077 | 2695 | 100 | 18 | 2021 | 35 | 2021-3557 |
| 15 | `z95_macro` | Z-95 Headhunter | anoat, blacksun, corporate, hapes, huttcartel, incom, kuat, mandodw, moncal, rendili, transgalmeg, valarian | 5000 | 1 | s_tabsx | 2749 | 70 | 8 | 2021 | 35 | 2021-3557 |
| 16 | `tie_fighter_van_macro` | TIE Fighter Vanguard | ascendancy, galempire, kuat, sienar | 3500 | 1 | s_novaldex60 | 2911 | 55 | 7.5 | 2021 | 35 | 2021-3557 |
| 17 | `tie_interceptor_rg_macro` | TIE Interceptor Royal Guard | galempire | 5500 | 1 | s_novaldex60 | 2911 | 55 | 7.5 | 2021 | 35 | 2021-3557 |
| 18 | `ship_xen_s_fighter_01_a_macro` | Unknown Ship | xenon | 4000 | 1 | xen_s_standard_01_mk2 | 3000 | 160 | 2 | 2050 | 100 | 745-3557 |
| 19 | `ship_xen_s_fighter_02_a_macro` | Unknown Ship | xenon | 11000 | 1 | xen_s_standard_01_mk2 | 3000 | 160 | 2 | 2050 | 100 | 745-3557 |
| 20 | `b22s_macro` | Belbullab-22s Scout | commerceguild, hoersh | 3550 | 1 | s_quintadq4 | 3018 | 60 | 9 | 2021 | 35 | 2021-3557 |
| 21 | `b22_macro` | Belbullab-22 | commerceguild, hoersh | 5250 | 1 | s_quintadq4 | 3018 | 60 | 9 | 2021 | 35 | 2021-3557 |
| 22 | `scarab_bomber_macro` | Scarab-class | commerceguild, hoersh | 5500 | 1 | s_quintadq4 | 3018 | 60 | 9 | 2021 | 35 | 2021-3557 |
| 23 | `hapan_s_macro` | Miy'til Starfighter | hapes | 6350 | 2 | s_cec1077+s_q7astro | 3045 | 120 | 0/18 | 2321 | 60 | 2121-4007 |
| 24 | `n1_macro` | N-1 Starfighter | naboo | 4500 | 2 | s_r2astrohead+s_cec1077 | 3145 | 125 | 0/18 | 2471 | 60 | 2471-4007 |
| 25 | `delta7_red_macro` | Delta-7B Aethersprite-class Interceptor | corporate, kamino | 5250 | 2 | s_tabsx+s_r2astro | 3199 | 95 | 0/8 | 2271 | 65 | 2121-4007 |
| 26 | `vwing_macro` | V-wing Nimbus Starfighter | corporate, kamino, moncal | 8500 | 2 | s_r2astrohead+s_tabsx | 3199 | 95 | 0/8 | 2471 | 60 | 2471-4007 |
| 27 | `rz1awing_macro` | A-wing RZ1 | newrepublic, rebelalliance | 4750 | 1 | s_zr41 | 3557 | 20 | 10 | 2021 | 35 | 2021-3557 |
| 28 | `m4_dune_macro` | G1-M4-C Dunelizard | mandodw, mandoraiders, valarian | 7000 | 2 | s_cec1077+s_cec1077 | 5390 | 200 | 18 | 4042 | 70 | 4042-7114 |
| 29 | `v19_macro` | V-19 Torrent Starfighter | corporate, kamino, moncal, valarian | 5500 | 2 | s_tabsx+s_tabsx | 5498 | 140 | 8 | 4042 | 70 | 4042-7114 |
| 30 | `r41_macro` | R-41 Starchaser | anoat, blacksun, hoersh, huttcartel, rendili, transgalmeg, valarian | 7150 | 2 | s_tabsx+s_tabsx | 5498 | 140 | 8 | 4042 | 70 | 4042-7114 |
| 31 | `quad_jumper_miner_macro` | TUG-b13 Quad Jumper Miner | anoat, corporate, huttcartel, incom, mandodw, rendili, transgalmeg, valarian | 10200 | 2 | s_tabsx+s_tabsx | 5498 | 140 | 8 | 4042 | 70 | 4042-7114 |
| 32 | `laat_macro` | LAAT/c | corporate, kamino | 15500 | 2 | s_tabsx+s_tabsx | 5498 | 140 | 8 | 4042 | 70 | 4042-7114 |
| 33 | `t70_xwing_orange_macro` | X-wing T70 O | incom | 8000 | 3 | s_cec1077+s_cec1077+s_q7astro | 5740 | 220 | 0/18 | 4342 | 95 | 4142-7564 |
| 34 | `ywing_btlbpm_macro` | Y-wing BTL-BPM | mandodw | 16000 | 3 | s_cec1077+s_cec1077+s_q7astro | 5740 | 220 | 0/18 | 4342 | 95 | 4142-7564 |
| 35 | `tie_phantom_macro` | TIE Phantom | ascendancy, galempire, sienar | 5150 | 2 | s_novaldex60+s_novaldex60 | 5822 | 110 | 7.5 | 4042 | 70 | 4042-7114 |
| 36 | `tie_shuttle_macro` | TIE Shuttle | ascendancy, galempire, kuat, sienar | 8000 | 2 | s_novaldex60+s_novaldex60 | 5822 | 110 | 7.5 | 4042 | 70 | 4042-7114 |
| 37 | `ywing_btlbp_macro` | Y-wing BTL-BP | anoat, huttcartel, valarian | 14000 | 3 | s_tabsx+s_tabsx+s_q7astro | 5848 | 160 | 0/8 | 4292 | 100 | 4142-7564 |
| 38 | `arc170_macro` | ARC-170 Starfighter | corporate, incom, kamino, moncal, valarian | 11000 | 3 | s_tabsx+s_tabsx+s_r2astro | 5948 | 165 | 0/8 | 4292 | 100 | 4142-7564 |
| 39 | `ywing_btlb_macro` | Y-wing BTL-B | corporate, kamino | 19000 | 3 | s_tabsx+s_tabsx+s_r2astro | 5948 | 165 | 0/8 | 4292 | 100 | 4142-7564 |
| 40 | `quad_jumper_macro` | TUG-b13 Quad Jumper Tug | blacksun, hoersh, huttcartel, mandodw, miningguild, rebelalliance, rendili, sith, transgalmeg, valarian | 10200 | 2 | s_zr41+s_zr41 | 7114 | 40 | 10 | 4042 | 70 | 4042-7114 |
| 41 | `ewing_macro` | E-wing E-07 | incom, newrepublic | 10750 | 2 | s_zr41+s_zr41 | 7114 | 40 | 10 | 4042 | 70 | 4042-7114 |
| 42 | `t70_xwing_blue_macro` | X-wing T70 B | newrepublic | 8000 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 43 | `t70_xwing_red_macro` | X-wing T70 R | rebelalliance | 8000 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 44 | `t65b_xwing_01_macro` | X-wing T65B | kuat, newrepublic | 8500 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 45 | `t65b_xwing_macro` | X-wing T65B | hapes, incom, rebelalliance | 8500 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 46 | `t65xj3_xwing_macro` | X-wing XJ-3/5 | incom, rebelalliance | 9500 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 47 | `ywing_btlnr2_macro` | Y-wing BTA-NR2 | newrepublic | 10000 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 48 | `ywing_btla4_macro` | Y-wing BTL-A4 | rebelalliance | 12000 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4342 | 95 | 4142-7564 |
| 49 | `ywing_btla4long_macro` | Y-wing Longprobe | corporate, incom, kuat, newrepublic, rebelalliance, rendili | 12000 | 3 | s_zr41+s_zr41+s_r2astro | 7564 | 65 | 0/10 | 4292 | 100 | 4142-7564 |
| 50 | `porax_38b_macro` | Porax-38-B Starfighter | huttcartel, valarian | 13500 | 3 | s_cec1077+s_cec1077+s_cec1077 | 8085 | 300 | 18 | 6063 | 105 | 6063-10671 |
| 51 | `kihraxz_macro` | Kihraxz Starfighter | anoat, blacksun, transgalmeg | 8300 | 3 | s_tabsx+s_tabsx+s_tabsx | 8247 | 210 | 8 | 6063 | 105 | 6063-10671 |
| 52 | `sith_supremacy_macro` | Supremacy Mark IV | sith | 7000 | 3 | s_novaldex60+s_novaldex60+s_novaldex60 | 8733 | 165 | 7.5 | 6063 | 105 | 6063-10671 |
| 53 | `tie_advanced_macro` | TIE Advanced | ascendancy, galempire, sienar | 8000 | 3 | s_novaldex60+s_novaldex60+s_novaldex60 | 8733 | 165 | 7.5 | 6063 | 105 | 6063-10671 |
| 54 | `tie_striker_macro` | TIE Striker | ascendancy, galempire | 14000 | 3 | s_novaldex60+s_novaldex60+s_novaldex60 | 8733 | 165 | 7.5 | 6063 | 105 | 6063-10671 |
| 55 | `porax_38_macro` | Porax-38 Starfighter | commerceguild | 11000 | 3 | s_quintadq4+s_quintadq4+s_quintadq4 | 9054 | 180 | 9 | 6063 | 105 | 6063-10671 |
| 56 | `sheathipede_macro` | Sheathipede-class transport shuttle | commerceguild, hoersh, miningguild | 12200 | 3 | s_quintadq4+s_quintadq4+s_quintadq4 | 9054 | 180 | 9 | 6063 | 105 | 6063-10671 |
| 57 | `m12_macro` | M12-L Kimogila | huttcartel, mandodw, mandoraiders, valarian | 18000 | 4 | s_cec1077+s_cec1077+s_cec1077+s_cec1077 | 10780 | 400 | 18 | 8084 | 140 | 8084-14228 |
| 58 | `laat_com_macro` | LAAT/i | corporate, kamino | 26000 | 4 | s_tabsx+s_tabsx+s_tabsx+s_tabsx | 10996 | 280 | 8 | 8084 | 140 | 8084-14228 |
| 59 | `tie_defender_macro` | TIE Defender | ascendancy, galempire | 8500 | 4 | s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60 | 11644 | 220 | 7.5 | 8084 | 140 | 8084-14228 |
| 60 | `victor_wing_macro` | Victor-wing | huttcartel, valarian | 14000 | 5 | s_cec1077+s_cec1077+s_cec1077+s_cec1077+s_cec1077 | 13475 | 500 | 18 | 10105 | 175 | 10105-17785 |
| 61 | `scurrg_h6_macro` | Scurrg H-6 | anoat, blacksun | 19000 | 5 | s_tabsx+s_tabsx+s_tabsx+s_tabsx+s_tabsx | 13745 | 350 | 8 | 10105 | 175 | 10105-17785 |
| 62 | `hwk_290_01_macro` | HWK-290 light freighter | anoat, bountyhunters, corellia, valarian | 28500 | 5 | s_tabsx+s_tabsx+s_tabsx+s_tabsx+s_tabsx | 13745 | 350 | 8 | 10105 | 175 | 10105-17785 |
| 63 | `bwing_macro` | B-wing A/SF-01 | newrepublic, rebelalliance | 19500 | 4 | s_zr41+s_zr41+s_zr41+s_zr41 | 14228 | 80 | 10 | 8084 | 140 | 8084-14228 |
| 64 | `tie_fury_e_macro` | TIE Fury /H | sith | 9000 | 5 | s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60 | 14555 | 275 | 7.5 | 10105 | 175 | 10105-17785 |
| 65 | `tie_scimitar_macro` | Scimitar Assault Bomber | galempire | 19000 | 5 | s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60 | 14555 | 275 | 7.5 | 10105 | 175 | 10105-17785 |
| 66 | `tie_echelon_macro` | TIE/es Echelon | ascendancy | 30000 | 5 | s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60 | 14555 | 275 | 7.5 | 10105 | 175 | 10105-17785 |
| 67 | `razorcrest_macro` | ST-70 Razor Crest | bountyhunters | 35000 | 6 | s_cec1077+s_cec1077+s_cec1077+s_cec1077+s_cec1077+s_cec1077 | 16170 | 600 | 18 | 12126 | 210 | 12126-21342 |
| 68 | `tie_reaper_macro` | TIE Reaper | galempire | 28000 | 6 | s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60+s_novaldex60 | 17466 | 330 | 7.5 | 12126 | 210 | 12126-21342 |
| 69 | `uwing_macro` | U-wing UT-60D | incom, kuat, newrepublic, rebelalliance | 16000 | 5 | s_zr41+s_zr41+s_zr41+s_zr41+s_zr41 | 17785 | 100 | 10 | 10105 | 175 | 10105-17785 |

## Files read

- **SWI ship macros:** `<SWI_UNPACKED>/ext/assets/units/size_s/macros/*_macro.xml`. This covers hull, component ref, display name and in-macro loadouts. The vanilla Kha'ak/Xenon/drone files are `<diff><replace>` patches.
- **SWI ship components:** `<SWI_UNPACKED>/ext/assets/units/size_s/<component>.xml`. These give the shield slot connections and tags, for example `tie_advanced.xml:622-634` and `tie_fighter.xml:566`.
- **SWI shield macros:** `<SWI_UNPACKED>/ext/assets/props/SurfaceElements/macros/shield_s_*_macro.xml`, plus the diff patches `shield_xen_s_standard_01_mk1_macro.xml` and `shield_xen_s_standard_01_mk2_macro.xml`.
- **SWI shield components:** `.../ext/assets/props/SurfaceElements/` (`shield_s_inv_standard.xml`, `shield_tie1.xml`, `shield_r2_s_standard_01_mk1.xml`, `shield_r2_s_standard_head.xml`, `shield_gnk_s_standard_01_mk1.xml`).
- **SWI indexes:** `<SWI_UNPACKED>/ext/index/macros.xml` and `components.xml`.
- **SWI libraries:**
  - `<SWI_UNPACKED>/ext02/libraries/wares.xml`: ware owners; removals at lines ~18345-18430; S shield wares at ~12791-13340
  - `shipgroups.xml`, `jobs.xml`, `god.xml`, `gamestarts.xml`: which macros are used
  - `loadouts.xml`: gamestart loadouts only
  - `loadoutrules.xml`: no shield rules
- **SWI text:** `<SWI_UNPACKED>/ext02/t/0001.xml` (page 999840) and vanilla `<X4_UNPACKED>/t/0001-l044.xml`.
- **Vanilla:**
  - 8.00 wares: `libraries/wares.xml` in `X4_UNPACKED` and the DLC folders next to it
  - **Caveat:** 8.00 assets aren't unpacked, so the vanilla Xenon/Kha'ak/drone ship components and `shield_kha_s_standard_01_mk1_macro.xml` were read from the unpacked **9.00** files. This only affects the Xenon/Kha'ak rows.

## Assumptions to verify in game

- **NPC loadouts only use shields whose ware the spawning faction owns, and level 1.0 fits the best of them.** Inferred from two measurements (TIE/x1 8733, TIE/LN 900), and consistent with both measurements, but not read from engine code.
- A faction other than the ship ware's owners narrows or changes the fit. For example, a TIE/x1 spawned for a non-Imperial faction gets a different fit.
- The three "no shields" ships (Yorik-et, `ship_xen_s_fighter_l`, unowned TIE Silencer) have not been seen in-game.
