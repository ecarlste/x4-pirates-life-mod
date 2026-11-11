# Capture operation under SWI 0.91 HF1 and X4 8.00

**Status: done (2026-11-11), from the files only; nothing run in game.** Answers [#105](https://github.com/ecarlste/x4-pirates-life-mod/issues/105): do the [capture operation](../specs/capture-operation.md)'s comm choice, mission readout and other diff patches work on X4 8.00 with SWI 0.91 HF1? Builds on [prior-art-better-piracy.md, Enhanced Bailing as bundled in SWI](prior-art-better-piracy.md#enhanced-bailing-as-bundled-in-swi) (SWI 0.90) and [third-party-ui-apis.md, How SWI builds its UI](third-party-ui-apis.md#how-swi-builds-its-ui).

Sources:
- **Vanilla 8.00:** `E:\x4-dev\reference\x4-8.00\` (`base\`, DLC folders), below `V:`.
- **SWI 0.91 HF1:** `E:\x4-dev\reference\mods\swi-0.91hf1\`, below `S:`. `starwarsmod_m1\` is the extension as shipped (`content.xml`, `ui.xml`, catalogs). `ext02\` is `ext_02.cat` unpacked (MD, AI scripts, libraries, text), `subst02\` is `subst_02.cat` (replacement menus), and `ext\` is `ext_01.cat` (assets, plus diffs for the DLCs' MD).
- **Ours:** `origin/main` at `037fa62`.

## Verdicts

| Patch or hook | Our file | 8.00 vanilla | 8.00 + SWI |
| --- | --- | --- | --- |
| Comm: `CanStart` check before the hostile hang-up | `md/conversations.xml:8` | Works as is | Works as is |
| Comm: keep hostile ships talking (`@value` replace) | `md/conversations.xml:19` | Works as is | Works as is |
| Comm: the choice, before `remove_value $locobject` | `md/conversations.xml:23` | Works as is | Works as is |
| Comm: our sections in `SectionHandler` | `md/conversations.xml:32` | Works as is | Works as is |
| Comm handler cue (`event_conversation_next_section`, NPC line 5036) | `md/apirateslife_capture.xml:272` | Works as is | Works as is |
| Mission readout (`create_mission`, `set_objective` + `progress`, `event_mission_aborted`, `remove_mission`) | `md/apirateslife_capture.xml:101–245` | Works as is | Works, but **the bail-check bar needs SWI's cooldown** (5 s, not 30 s) |
| No missiles, in sight | `aiscripts/fight.attack.object.fighter.xml:9` | **Needs new selectors** | **Needs new selectors** (SWI doesn't touch these lines) |
| No missiles, out of sight | `aiscripts/fight.attack.object.fighter.xml:12` | **Needs a different hook** (8.00 has no `$firemissiles`) | Same |
| Bail hook: `AdjustEjectChance` before the roll | `md/notifications.xml:6` | Works as is | Selector matches SWI's block, **only if we load after SWI**; the wing ×4 is then wrong |
| Bail hook: `Bailed` signal | `md/notifications.xml:38` | Works as is | Matches, **only if we load after SWI** |
| Intact on eject (`$damageminpercent`, `$scuttle`) | `md/notifications.xml:22, 27` | Works as is | No match (SWI has no such lines); harmless, but logs patch errors |
| Intact on claim (`$damagemaxpercent`) | `aiscripts/move.claim.xml` | Works as is | Works as is (SWI doesn't patch `move.claim.xml`) |
| Order icon | `libraries/icons.xml` | Works as is | Works as is |

So, for the SWI build:
1. Rewrite the no-missiles patch for 8.00 (below).
2. Make SWI load before us, with an optional dependency, or SWI's Enhanced Bailing replace wipes the bail hook.
3. Under Enhanced Bailing, don't undo a ÷4 that isn't there, and read the bail cooldown as data, not as 30 s.

The comm choice and the mission readout themselves need no change.

## Comm choice

**Vanilla 8.00** (`V:base\md\conversations.xml`), each of our selectors matches exactly once:
- `DefaultComm` is the first cue (line 6). `$surrenderoption` and `$maysurrender` are set at lines 22 and 24, inside `actions/do_if[1]`.
- The hostile hang-up is `do_if` line 36. Its `@value` string is identical to the one our patch selects (`grep -cF` = 1).
- The non-player pilot's branch has the surrender choice at lines 118–125 (`top_left`), cargo drops at 130 and 134 (`left`, `bottom_left`), and `<remove_value name="$locobject"/>` at line 139. That's the only `remove_value $locobject` in the file, so our `position="right"` choice lands there, in a slot that branch doesn't use.
- `SectionHandler` starts at line 304. Its catch-all `do_elseif` (`event.param != 'g_finish' and …`) is at line 1065, with the "Unexpected section" error at 1066.
- The only DLC diff on this file is `V:ego_dlc_timelines\md\conversations.xml`. It adds conditions to `DefaultComm/conditions` (off in the refugee scenarios), not to anything we select.

**SWI** patches `conversations.xml` with a diff, not a replacement (`S:ext02\md\conversations.xml`, 65 lines):
- Lines 6–9 replace `/mdscript/cues/cue[1]/actions/do_if[1]/set_value[4]`, vanilla's `$maysurrender` (line 24). Its version drops the S/M class check and lowers the hull gate from 75% to 50%. That's inside `do_if[1]`. Our first `add` goes before the hostile `do_if`, a later sibling, so `do_if[1]` keeps its index whichever mod loads first. No conflict.
  - Side effect worth knowing: under SWI, vanilla's own "Surrender!" choice shows as selectable for any capturable class under 50% hull, while SWI's bail roll still gates at 75% (`S:ext02\md\notifications.xml:54`). The comment on SWI's line 4 says these should match, and they don't. That's SWI's issue, not ours.
- Lines 17 and 43 replace the friendly greeting line in `Greeting` and `Greeting_NPCTemplate` (kuertee's professions). We don't select those.
- Nothing in SWI's MD names `DefaultComm`'s hang-up, `remove_value $locobject` or `SectionHandler`. `grep -rl SectionHandler` over `S:ext02\md` and `S:ext\extensions` finds nothing.

**SWI's Extended Conversation Menu** (`S:ext02\md\extendedconversationmenu.xml`, a new `mdscript`) listens to the same `event_conversation_started conversation="default"` (line 23).
- It adds one unpositioned "… more. (Mods)" choice (line 37), but only when a mod has registered an option for this conversation.
- The registrations in SWI are kuertee's guild-member and representative talks (`kuertee_professions.xml:3052–3184`) and the bounty talk with a station's trade NPC (`kuertee_emergent_missions.xml:12104–12150`). None of them is a hostile ship's pilot.
- So our choice and ECM's don't compete for a slot in the comm we care about. ECM's own `position="right"` "Next page" (line 78) is only in its own section.

**The comm UI itself is native.** Vanilla 8.00 has no conversation addon in `ui\addons\`, and SWI replaces no core UI (`subst_02.cat` only lists `ui\addons\…` menus). The interact menu's "Comm" entry still goes through `menu.buttonComm` → `Helper.returnFromInteractMenu(…, "comm", …)` in SWI's replacement (`S:subst02\ui\addons\ego_interactmenu\menu_interactmenu.xpl:1863–1875`), as in vanilla (`menu_interactmenu.lua:1832–1844`).

**The handler cue** uses NPC line 5036, which vanilla 8.00 uses too (`conversations.xml:664`). SWI doesn't use our text page 1774100 (`grep` over `S:ext02\t` finds nothing).

## Mission readout

Everything the readout uses exists in 8.00 with the same shape:
- `create_mission` with `abortable` (`V:base\libraries\md.xsd:2511`, attribute at 1463; vanilla's `gm_escort.xml:577` passes `abortable="true"`).
- `<objective … action="objective.custom">` in the briefing, and `set_objective` with a `<progress>` child (`md.xsd:3842`). Vanilla's `boarding.xml` does the same: objectives at 304, `set_objective` at 842, a progress bar at 376.
- `event_mission_aborted` (`diplomacy.xml:1123`, `gmc_supervised_mining.xml:1160`).
- `iscapitalship` (`scriptproperties.xml:791`) and `iscapturable`.

SWI leaves this alone:
- **No MD change to mission creation:** of SWI's `ext02\md` files that mention `create_mission`, the only diff is a story script (`x4ep1_war_subscriptions.xml`). The rest are SWI's own new scripts.
- **The HUD objective display is native.** SWI replaces no `ui\core` file.
- **The map's mission list is replaced** (`subst02\ui\addons\ego_detailmonitor\menu_map.xpl`): it's kuertee's UI Extensions version, with collapsible mission lists (`uix_expandMissionList`). Aborting works as in vanilla: `C.AbortMission(menu.contextMenuData.missionid)` at SWI line 3546 vs vanilla `menu_map.lua:3481`, with `abortable` read the same way (SWI 19084/19117 vs vanilla 17925/17958). `menu_missionbriefing` isn't replaced.

**What needs to change: the bail-check bar.** Step 3 of the readout (`md/apirateslife_capture.xml:176–185`) assumes vanilla's 30 s cooldown: the bar's max is 30, and the wait is clamped to 30.
- Vanilla 8.00 sets `$nextcapturechance` to `player.age + 30s` (`V:base\md\notifications.xml:1308`).
- SWI's Enhanced Bailing sets `player.age + 5s` (`S:ext02\md\notifications.xml:170`).
- Under SWI the bar would sit between 25 and 30 of 30 and never read as a countdown.
- The cooldown should come from profile data, or from the gap between two observed `$nextcapturechance` values. This is also where the nerve readout ([#96](https://github.com/ecarlste/x4-pirates-life-mod/issues/96)) plugs in.
- The 20% shield and 75% hull steps still match SWI's roll gate (`S:ext02\md\notifications.xml:54`).

## No-missiles patch (`fight.attack.object.fighter.xml`)

Both of our selectors are 9.x lines that 8.00 doesn't have. `grep` for `firestorpedo` and `firemissiles` in `V:base\aiscripts\fight.attack.object.fighter.xml` finds nothing. In 9.00 they're at lines 56, 58, 175, 374, 561–563, 713 and 832. As shipped, both patches fail to apply on 8.00 (a diff error in the log), and wingmen fire missiles and torpedoes again: the kills the patch exists to prevent.

**In sight, needs new selectors.** 8.00's missile-pass check is at line 331:

```xml
<do_if value="not $target.isclass.ship_xs and ((not this.ship.dps.lasers.all and this.ship.dps.missiles.all) or (this.ship.dps.missiles.all gt 0 and player.age gt $delaymissiles))">
```

That's one match. The same `@value` replace works with this string, appending `and not @this.$APiratesLife_NoMissiles`. 8.00 also sets an initial `$delaymissiles` (line 184: 10–20 s at skill 5, up to 60–120 s at skill 0), so "missiles from the first pass" (the spec's 9.x note) doesn't hold on 8.00. The patch is still needed.

**Out of sight, needs a different hook.** 8.00 has no `$firemissiles` gate:
- `get_attackstrength` at line 654 (in `attention[@min='unknown']`) always returns missile results (`<missileresult ammo="$spentammotable" impacting="$impactingammotable" …/>`, line 656). Lines 659–664 then remove the spent ammo.
- Formation followers add their missile damage at lines 670–692.
- Line 733 checks `$result_missile*`, and line 783 applies the missile damage with `apply_attackstrength … explosion="true"`.

A hook that does what ours does, while the flag is set:
1. **Right after the leader's `get_attackstrength`:** add `pos="after"` on `//attention[@min='unknown']//get_attackstrength[@object='this.assignedcontrolled'][missileresult]` (line 654; the one at line 95 is in a `<patch>` and has no `missileresult`). Set `$spentammotable` and `$impactingammotable` to `table[]` and the four `$result_missile*` to 0. That way no ammo is spent and no damage is applied.
2. **Before the damage check at line 733:** zero the four `$result_missile*` again and empty `$impactingammotable`, so a formation follower's missiles don't count either. A selector such as `//attention[@min='unknown']//do_if[contains(@value, 'or $result_missilehullshield or')]` would do. That `@value` spans two lines, so match a fragment with `contains()`.

The flag name and the "vanilla unchanged without the flag" rule stay. The new selectors need a check on the 8.00 files: run our patch applier, or check the game log for diff errors.

**SWI and this file:** SWI's diff (`S:ext02\aiscripts\fight.attack.object.fighter.xml`, 8 lines) adds one `do_if` before `attention[@min='unknown']/actions/do_while/do_if[contains(@value, 'not $duration_movement? or')]` (vanilla line 634). It doesn't touch lines 331, 654 or 733, so load order doesn't matter here.

**Related scripts SWI patches:**
- `order.fight.attack.object.xml`, which our order runs with `run_script`, gains an `acquireonsight` param, an out-of-sight target-switch condition, and kuertee's emergent-missions `kEM_AttackStart`/`kEM_AttackFinish` at the `fight`, `acquirenewtarget` and `finish` labels and in `on_abort` (`S:ext02\aiscripts\order.fight.attack.object.xml`).
- All the params we pass (`primarytarget`, `allowothertargets`, `checkrelation`, `pursuetargets`, `internalorder`, `debugchance`) exist in 8.00 (`V:base\aiscripts\order.fight.attack.object.xml:20–77`).
- Nothing there breaks our order. Whether kEM counts our op as an attack on a faction is a question for play.

## Bail hook (`md/notifications.xml`)

The capture op depends on it for the wing's ×4 and `$lastchance`, which the readout shows.

**Vanilla 8.00:** all four selectors match in `PlayerOwnedShipAttacks` (cue at line 1185):

| Selector | Line |
| --- | --- |
| The roll `do_if[@chance='if not $testcheat? then $ejectchance else 100']` | 1276 |
| `$damageminpercent` | 1297 |
| `$eject?` | 1325 |
| `remove_value $numcrewbailing` | 1334 |
| `$scuttle` | 1337 |

The ÷4 for attackers the player isn't flying is at lines 1265–1267.

**SWI** replaces the whole `do_if[@value='$target.iscapturable']` with Enhanced Bailing (`S:ext02\md\notifications.xml:45–311`). The 0.91 HF1 copy matches the 0.90 notes in [prior-art-better-piracy.md](prior-art-better-piracy.md#enhanced-bailing-as-bundled-in-swi):

| Our selector | In SWI's block |
| --- | --- |
| The roll | Line 108, `<do_if value="true" chance="if not $testcheat? then $ejectchance else 100">`: matches |
| `$eject?` → `remove_value $numcrewbailing` | Lines 187 → 196: matches |
| `$damageminpercent` | Only in a comment (line 160): no match |
| `$scuttle` | Absent (the scuttle effect at 246 is cosmetic; the weapon destruction at 254 is commented out): no match |

**Load order decides whether any of it survives.**
- If our diff applies first, SWI's `replace` swaps out the whole block and removes the nodes we inserted inside it: no `AdjustEjectChance`, no `Bailed` signal, so no metrics, pirated marks or `$lastchance`.
- If SWI applies first, our two inserts land in its block.
- Our `content.xml` declares no dependency on SWI.
- Fix: an optional dependency on SWI, like the one on UI Extensions.
  - SWI's `content.xml` id is `SW Interworlds` (with a space). The shipped folder is `starwarsmod_m1`.
  - Which one a `<dependency id=…>` must name, and the order X4 uses with no dependency, aren't settled by these files. Check the extension list in `debuglog.txt` once it's added.

**The wing ×4 is wrong under SWI.** Enhanced Bailing has no ÷4 for attackers the player isn't flying: it halves for combat S/M ships, line 103, for every attacker. Our `AdjustEjectChance` multiplies op members by 4 (`md/apirateslife_bail.xml:25–30`), so under SWI a wingman's check would be 4× the player's, not equal. Whether vanilla's ÷4 is there is universe data: put it in the profile, or turn `CaptureWingFullChance` off on SWI.

**Intact on eject** finds nothing to patch under SWI. SWI has no hull drop, but it still removes some cargo (lines 234–239). Each missed selector logs a diff error at load. For a clean log on SWI, drop these two inserts from the SWI build, or accept the errors.

## What SWI overwrites outright

**Whole-file replacements** (`starwarsmod_m1\subst_02.cat`: a substitution catalog, so these replace vanilla's files). All 20 are UI menus, carrying kuertee's UI Extensions:
- `ego_detailmonitor\`: `menu_diplomacy`, `menu_docked`, `menu_encyclopedia`, `menu_map`, `menu_playerinfo`, `menu_research`, `menu_scenario_debriefing`, `menu_scenario_selection`, `menu_ship_configuration`, `menu_station_configuration`, `menu_station_overview`, `menu_toplevel`, `menu_trader_blueprintsorlicences`, `menu_transactionlog`, `menu_transporter`, `menu_userquestion` (all `.xpl`).
- `ego_detailmonitorhelper\helper.xpl`.
- `ego_gameoptions\customgame.xpl`, `ego_gameoptions\gameoptions.xpl`.
- `ego_interactmenu\menu_interactmenu.xpl`: it also carries SirNukes' Interact Menu API hooks (`Interact_Menu_API.*` events, "mycu" custom action and order groups). That matters for the planned right-click entry, not for the comm choice.

The other two substitution catalogs hold no scripts: `subst_01.cat` has loading screens and English voice, and `subst_03.cat` has DLC loading screens.

None of our capture-op patch targets is replaced outright:
- **MD and AI scripts:** every SWI file in `ext02\md` or `ext02\aiscripts` that shares a name with a vanilla 8.00 file is a `<diff>`. The 42 MD and 2 AI scripts that aren't diffs are new names that vanilla doesn't have.
- **Libraries:** three non-diff files share a vanilla name: `libraries\macro.xml`, `libraries\stances.xml` (and `modding_notes.xml`, which vanilla doesn't have). We patch neither.
- **SWI's DLC MD** (`ext\extensions\ego_dlc_*\md`, 32 files) is all diffs, and none of them is `conversations.xml` or `notifications.xml`.

The closest thing to an overwrite that hits us is the `replace` of the bail block in `notifications.xml` (above).

## Open questions

- The extension id X4 matches for a dependency on SWI (`SW Interworlds` or the folder name), and X4's load order with no dependency between two extensions. Check in the game log.
- Whether kuertee's emergent missions, through SWI's `order.fight.attack.object` patch, treat a capture op's fighting as a crime or a bounty.
