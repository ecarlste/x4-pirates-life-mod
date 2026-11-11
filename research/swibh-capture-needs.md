# What swibh needs from capture (2026-11-10)

Research for [#92](https://github.com/ecarlste/x4-pirates-life-mod/issues/92) on the map [#89](https://github.com/ecarlste/x4-pirates-life-mod/issues/89). Feeds the contract grilling [#94](https://github.com/ecarlste/x4-pirates-life-mod/issues/94).

Question: what does `swibh` (the bounty hunter extension, [x4-swi-bounty-hunter](https://github.com/ecarlste/x4-swi-bounty-hunter)) need from A Pirate's Life's capture, at launch and later? What would it read, call or wait for, by which episode, and what does it do when A Pirate's Life isn't installed?

Sources: the bounty hunter repo at `origin/main` `f8d00da` (`GLOSSARY.md`, `design.md`, `concept.md`, `HANDOFF.md`, `mods.md`, ADRs 0001-0002, `extension/swibh/`, `tools/log/schema.ts`, `research/`), its research branches, and its issues [#49](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/49), [#11](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/11), [#50](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/50), [#51](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/51), [#13](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/13), [#84](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/84), [#48](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/48), [#66](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/66), [#72](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/72), [#74](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/74), [#77](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/77) and the map [#1](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/1). A Pirate's Life at `main` `f407694`. SWI 0.91 HF1 unpacked at `E:\x4-dev\reference\mods\swi-0.91hf1`. Read from source and tickets only; nothing run in game.

Tags: **[read]** = seen in the cited source. **[inferred]** = my reading, not stated anywhere. In the table, **decided** = written in a resolved bounty hunter ticket or its docs; **assumed** = the bounty hunter side relies on it but no ticket settles it, or it's my inference.

## Short answer

The bounty hunter side has decided one thing firmly: capture is all A Pirate's Life, and `swibh` builds one hook, "capturing a hunt's target counts as the kill". Everything else it needs from A Pirate's Life is implied, not specified. No `swibh` code references A Pirate's Life yet [read: `git grep apirateslife` in `extension/` and `tools/` finds nothing].

| Need | By | Decided / assumed | Source |
| --- | --- | --- | --- |
| S/M capture works on 8.00 + SWI (bail, marine claim, ship arrives intact) | Launch (ep. 1); the trial before the version lock | Decided | [#11](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/11), [#49](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/49), [#84](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/84) |
| Captures happen often enough for "capture-first" (the trial's bar) | Version lock, before launch | Decided (the bar); the tuning is open | [#84](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/84) |
| Saving Shaddo's fallback: capture an S on the first bounty | Ep. 1 cut or ep. 2, only in two outcomes | Decided (the beat); how the questline sees it is assumed | [#50](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/50), `concept.md` 70-85 |
| A "this ship is now the player's, taken from X" event (A Pirate's Life's `Decided` / pirated mark) | Ep. 1 fallback, then ep. 2 | Assumed | [inferred] from #49, #48 |
| Capture-as-kill: taking a hunt's target ends the hunt and pays as a kill | Ep. 2 (stage 1 core) | Decided (the rule); which signal and which moment are open | [#49](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/49), [#11](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/11), `GLOSSARY.md` Capture, Target |
| Who took it: the capture's attacker (player-owned?) and target, and how (bail or boarding) | Ep. 2 | Assumed | [inferred] |
| Capture of loyal wingmen and pirates is "fair game" | Ep. 2 onward | Decided (fair game); whether a captured wingman pays like a killed one is open | [#49](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/49), `design.md` 44 |
| A bail signal with the target and whether the pilot left, for Dead or Alive pod chase | Later in stage 1, before the first target that bails | Assumed (swibh's research plans its own vanilla event) | [#51](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/51), `research/alive-capture.md` |
| A capture log event for `swibh`'s hunt log (and edit markers) | Ep. 2 [inferred] | Assumed | [#48](https://github.com/ecarlste/x4-swi-bounty-hunter/blob/research/pirates-mod-capture/research/pirates-mod-capture.md) section 5, `tools/log/schema.ts` |
| Scripted ejects (Shaddo, the nemesis) are `swibh`'s own and must not be disturbed by A Pirate's Life | Launch (ep. 1) | Assumed (nobody has asked) | [#66](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/66), [inferred] |
| L/XL "wing disables, then boards" capture order | Before stage 3 | Decided as the plan; out of #89's scope; fallback: a save extractor | [#49](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/49), [#11](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/11) |
| `swibh` works fully without A Pirate's Life; capture features are "APL integrations" that switch on only when it's installed | Release (after stage 1 airs) | Decided (the rule); the detection is open | [#13](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/13), `GLOSSARY.md` Plays well with, APL integration |
| Prisoners | Never from A Pirate's Life | Decided: `swibh` builds its own | [#51](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/51), map #89 Out of scope |

## Details

### 1. What "capture" means on the bounty hunter side

- **Capture** is "taking a ship for the player by making its crew bail, or by boarding it, then claiming it with a marine, who flies it until a character or a better pilot takes over. Fair game is a hunt's target, its loyal wingmen and any pirate. Capturing a hunt's target counts as killing it." [read: `GLOSSARY.md`, Capture]
- **A target's** "death or capture ends every hunt on it, and each hunt the player holds on it pays." [read: `GLOSSARY.md`, Target]
- "Capture is all done by A Pirate's Life (our own mod); `swibh` builds no capture code." [read: #49 resolution]. The map #1 says the same: "Anything piratey (bailing, boarding, captures, piracy) comes from our own mod". [read: #1 body]
- "The one `swibh` hook: taking the target's ship counts as the kill. The adapter debriefs the hunt and pays the normal bounty. What happens to the pilot is a matter for Alive bounties." [read: #49]. Decided.
- **The marine:** Bobby's ship carries at least a pilot and a marine, or a wing ship carries the marine, except at the very start before he can afford one. The marine claims the capture and pilots it. [read: #49]. So the claim step is vanilla's marine claim, with A Pirate's Life's intact-on-claim [inferred].

### 2. By episode

**Before launch: the trial ([#84](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/84)).** The launch-day version lock waits only on it [read: #1 decision on #62]. The bar: "surrenders and bails happen often enough for capture-first, and claimed ships arrive intact." It loads the 8.00 + SWI build with the series mods, checks `debuglog.txt` for failed patches, and plays one hunt [read: #84 body]. Decided. Note: the map #89 has "no raised bail chance by default" because SWI already raises it [read: #89 Notes], so "often enough" rests on SWI's own Enhanced Bailing plus the capture operation and bail pressure [inferred].

**Launch: episode 1 (stage 0).**
- #11 lists "A Pirate's Life's S/M capture port (that repo; launch depends on it)" [read]. Decided.
- The episode's S target "and capturing it, are part of the questline's script, not a `swibh` hunt" [read: #11]. So capture-as-kill is not needed at launch [read]: there is no hunt to end.
- Saving Shaddo's outcomes: if no escort R-41 survives, "Bobby captures an S on his first bounty and the newbie flies it"; if Shaddo dies, "Bobby captures an S on his first bounty and recruits its pilot" [read: `concept.md` 74-75, #50]. "The capture fallback adds one quick stage 1 fight and makes the cut 5-10 min longer" [read: `concept.md` 85]. So in two of four outcomes, an S capture is on camera in episode 1's cut [read].
- "Captures assume A Pirate's Life's S/M port is ready at launch." [read: `concept.md` 86, #50]
- What the questline must know [inferred]: that the S is now the player's (to seat the newbie, or to "recruit its pilot"). A Pirate's Life's `md.APiratesLife_Pirated.Decided` (table `$ship`, `$how`) gives that [read: `md/apirateslife_pirated.xml` 59-65, 139]. Vanilla's `event_contained_object_changed_true_owner` gives it too, without A Pirate's Life [read: same file 95-98 uses it]. Not decided which.
- **"Recruits its pilot" conflicts with how capture works** [inferred]: after a bail the pilot leaves in a pod and the marine flies the ship (#49, #51 facts); after boarding the pilot is deleted ([alive-capture.md](https://github.com/ecarlste/x4-swi-bounty-hunter/blob/research/alive-capture/research/alive-capture.md) table rows 1-2). A Pirate's Life keeps no pilot. So that beat needs `swibh` script (e.g. a scripted pilot spawn), not A Pirate's Life [inferred].
- **Scripted ejects are `swibh`'s own.** Shaddo's eject is `eject_npcs spacesuit="true" force="true"` behind `SetShipMinHull`; the nemesis needs the same floor plus a scripted retreat [read: #66 resolution, [dirty-jobs-missions.md](https://github.com/ecarlste/x4-swi-bounty-hunter/blob/research/dirty-jobs-missions/research/dirty-jobs-missions.md) 68-74]. A scripted `eject_npcs` doesn't pass through `PlayerOwnedShipAttacks`, so A Pirate's Life's bail hook and `Bailed` never see it [inferred from `md/notifications.xml` 39, where `Bailed` is signalled]. The risk runs the other way: a normal combat bail roll (SWI's, with our hook) could make the nemesis or Shaddo bail early, before the script's eject. Nobody has looked at this [inferred].
- The dirty job "debt from a late payer" beats a ship down (`GM_RetrieveItem`, `RML_Enforce_Surrender`) [read: #66]. A bail there would end the job differently [inferred; not raised anywhere].

**Episode 2 (stage 1 core).**
- Ready before episode 2's session: "the hunt model and SWI adapter, ... capture-as-kill, refit with stock builds and bounty-hunter paint, and a small rename pilot action" [read: #11]. Decided.
- "Build work (ordinary issues, off the map): the capture-as-kill hook" [read: #49]. It's `swibh` code. What it reads from A Pirate's Life isn't specified [read: no ticket says].
- **What SWI already does** [read: SWI 0.91 HF1 `ext02/md/kuertee_emergent_missions.xml` 6275-6281]: its hunt's `Mission_Hunt_TargetManager_Destroyed` fires on `event_object_destroyed` **or** `event_object_abandoned` of the target. If the player attacked it, that is `destroy_success` [read: `research/swi-bounty.md` 150-152]. So a full bail of the target already counts as the kill in SWI's stock hunt, with no A Pirate's Life code [read].
- **What isn't covered:** a boarded target (owner change, no abandon) has no handler; "the mission waits for the timeout" [read, marked unverified there: `research/hunt-logging-hooks.md` 29]. `swibh`'s own `hunt.kill` log event only fires on `event_object_destroyed` [read: `extension/swibh/md/swibh_hunt.xml` Watch_Kill], and `hunt.kill` has roles `target`/`escort` only, no capture [read: `tools/log/schema.ts` 222-226]. So capture-as-kill needs at least a log change, and boarding needs a real hook [inferred].
- **Which moment counts** is open [inferred]: the bail (abandon, when SWI already resolves), or the claim (owner change, when A Pirate's Life's `Decided` fires). SWI destroys unclaimed bailed ships after 30-70 min [read: #48 gist], so a bail that's never claimed still "counts" in SWI's hunt today.
- Refit needs "a pilot aboard (the marine or a character)" [read: #49]. That's the marine claim, not A Pirate's Life code [inferred].
- Build names are logged from episode 1 [read: #11]; not capture-related.

**Later in stage 1.**
- **Dead or Alive** ([#51](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/51)), "before the first target that bails" [read: #11]. When the target's crew bails, its pod becomes something to chase; within about 1 km a script moves the pilot aboard as a prisoner [read: #51]. Build work is all `swibh`'s: pod tracking, the prisoner, the waypoint, the handover, the delivery event [read: #51]. Its research plans to catch the pods with vanilla's `event_object_dropped_objects` on the target, and suggests a `swibh` diff on SWI's pilot bail in `md/notifications.xml` [read: alive-capture.md table row 3 and line 82]. A Pirate's Life's `Bailed` signal (table `$attacker`, `$target`, `$crew`, `$pilot`) [read: `md/apirateslife_bail.xml` 47-55, `md/notifications.xml` 39] could serve the "pilot bailed" moment, but no ticket says so [inferred]. A `swibh` diff on the same SWI bail block A Pirate's Life patches is a conflict risk [inferred].
- **Loyal wingmen:** "Each one *killed* adds 50% of a new reward roll" [read: `design.md` 44]. They're fair game for capture [read: #49], but whether a captured loyal wingman pays like a killed one isn't said anywhere [read: no source].
- **Sector bounties and retainers** ([#77](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/77)): paid per kill [read: #1 decision]. Whether a captured pirate counts as a kill there isn't said [read: no source].
- **Our own hunts** ([#74](https://github.com/ecarlste/x4-swi-bounty-hunter/issues/74)): "the pay rises until death or capture" [read: #1 decision]. So capture also ends the target's kill-count pay [read].

**Stage 2 and 3.**
- Before stage 3: "A Pirate's Life's L/XL wing-disables-then-boards capture" [read: #11]. "We rely on it being ready when the L rung arrives"; if not, "a TypeScript extractor lists every abandoned ship and its sector from the new playthrough save" [read: #49]. Out of #89's scope (L/XL is its own map) [read: #89 Out of scope]. Under SWI, civilian L/XL can bail their pilot; military L/XL keep half their crew and need boarding [read: #48 gist]. Capture-as-kill must then work on boarding, not just bails [inferred].

**Release (after stage 1 airs).**
- `swibh` "works fully with only SWI installed, and a run with only SWI is a gate" [read: #13]. A Pirate's Life is listed as a mod that **plays well with** `swibh`, "not as a dependency. Features that need it are APL integrations that turn on only when it's installed (capture-as-kill and the S capture beat, for example)." [read: #13; `GLOSSARY.md` APL integration]. Decided.
- **Uninstall** of `swibh` must leave a playable save [read: #13]; nothing there about A Pirate's Life being removed under `swibh` [read: no source].
- **One supported SWI version**, with diff patches on SWI's MD that "fail soft and log a warning" [read: #13]. Both mods patch SWI or vanilla MD [read: #48, swibh `content.xml` comment], so both carry this rule [inferred].

### 3. What swibh would read, call or wait for

Nothing below is specified on the bounty hunter side; these are the A Pirate's Life hooks that exist today and the bounty hunter need each could serve [read: the A Pirate's Life files; the mapping is inferred].

| A Pirate's Life hook (9.x `main`) | Carries | Could serve | Ports to the SWI build |
| --- | --- | --- | --- |
| `md.APiratesLife_Bail.Bailed` (signal) | `$attacker`, `$target`, `$crew` (count), `$pilot` (whether the pilot bailed) [read: `md/notifications.xml` 39] | Dead or Alive's "target bailed, chase the pod"; a bail log event | Yes [read: #48 section 1] |
| `md.APiratesLife_Pirated.Decided` (signal) | `$ship`, `$how` (`'bail'`, `'boarding'`, or null for a donation) [read: `md/apirateslife_pirated.xml` 59-65] | Capture-as-kill at the claim; the Shaddo fallback's "S is ours" | Yes, as is [read: #48 section 5] |
| `md.APiratesLife_Pirated.IsPirated` (library) and `global.$APiratesLife_PiratedShips` | `$how`, `$from` (the faction it was taken from), `$time` [read: same file 11-12, 36-42] | Which faction lost the ship (hunt's target faction check) | Yes |
| `md.APiratesLife_Capture.Started` / `Ended` (signals) | `$target`, `$leader`, `$members`; then `$target`, `$outcome` = `destroyed`, `captured`, `abandoned`, `calledoff` or `escaped` [read: `md/apirateslife_capture.xml` 117-155, 250-268] | An engagement or capture log event; edit markers | Mostly; the no-missiles patch needs new selectors [read: #48 section 4] |
| `[apirateslife] capture metrics: ...` debug line | One line per attempt [read: `md/apirateslife_metrics.xml` 172] | Not `swibh`'s log schema (ADR 0001 wants `[swibh]` lines from one schema) [read: ADR 0001] | Not in the port list [read: #87] |

Gaps [inferred]:
- No hook says "this hunt target was taken". `Decided` fires for any ship that becomes the player's; `swibh` would match it against its open hunts itself.
- `Decided` fires at the owner change, after the marine claims. `Bailed` fires at the bail. SWI resolves the hunt at abandon. The contract has to pick one moment.
- Boarding: `Decided` with `$how = 'boarding'` covers vanilla boarding, since A Pirate's Life marks it [read: `md/apirateslife_pirated.xml` 85-93]. That would cover the SWI hunt's boarding gap [inferred].
- No scripted-eject flag: A Pirate's Life can't tell a `swibh` scripted eject from a combat bail, and doesn't need to, since it never sees one [inferred].

### 4. When A Pirate's Life isn't installed

- **Decided:** `swibh` works fully with only SWI; capture-as-kill and the S capture beat are APL integrations that switch on only when it's installed [read: #13].
- **What still happens without it** [inferred]: SWI's Enhanced Bailing still makes crews bail, the marine can still claim (vanilla `move.claim`, with its hull and equipment damage), and SWI's stock hunt already counts an abandoned target as destroyed. Boarding still works through vanilla. So without A Pirate's Life a player loses the capture operation, intact claims, the pirated mark, and `swibh`'s capture-as-kill for boarded targets.
- **Shaddo's fallback without it** is not settled [inferred]: #13 names "the S capture beat" as an APL integration, but the questline runs "for every player" in a new Bankrupt Bounty Hunter game [read: #50]. What replaces the beat (cash, a scripted ship, plain SWI capture) isn't written.
- **How `swibh` knows it's installed** isn't decided [read: no source]. Options [inferred]: an optional `<dependency id="apirateslife" optional="true"/>` in `swibh`'s `content.xml` (load order only), plus a runtime check that A Pirate's Life's cues exist before listening. A Pirate's Life's `content.xml` already uses an optional dependency for kuertee's UI Extensions [read: `content.xml` 6]. Signal listeners on a missing cue would fail at load [inferred; check in game].

## Open questions for #94 (the contract grilling)

1. **Direction:** A Pirate's Life knows nothing of `swibh`, and `swibh` listens to A Pirate's Life's signals behind an optional dependency? Or does A Pirate's Life call into `swibh`? #13 implies the first.
2. **The moment of "counts as the kill":** the bail (abandon, when SWI's hunt already resolves), or the claim (owner change, `Decided`)? What if a bailed target is never claimed and SWI destroys it 30-70 min later?
3. **Boarded targets:** SWI's hunt has no handler for an owner change. Does `swibh`'s capture-as-kill use `Decided` with `$how = 'boarding'`, or vanilla's owner-change event directly (which works without A Pirate's Life)?
4. **Is capture-as-kill really an APL integration?** SWI already counts an abandoned target. Only boarding and `swibh`'s own log need more, and vanilla events can give both. Which part needs A Pirate's Life?
5. **Stable names:** which cue names and table fields (`Bailed`, `Decided`, `Started`, `Ended`, `IsPirated`, their params) become the public contract, versioned how, and do they hold between the SWI build and the 9.x line?
6. **Attribution:** does a capture by a wingman (or the marine of a wing ship) count as the player's kill, matching SWI's "player attacked it" rule and `hunt.kill`'s `byPlayer`?
7. **Fair game beyond the target:** does a captured loyal wingman pay the 50% wingman bonus? Does a captured pirate count for a sector bounty or retainer?
8. **Scripted ejects and set pieces:** must A Pirate's Life leave Shaddo, the nemesis and the dirty-job payer alone (no capture comm choice, no bail roll changes), and how does `swibh` mark them (e.g. a blackboard flag A Pirate's Life checks)?
9. **The bail block on SWI's `md/notifications.xml`:** A Pirate's Life patches it; Dead or Alive's research proposes a `swibh` diff there too. Who owns that block, and can Dead or Alive use `Bailed` instead?
10. **"Recruits its pilot"** (Shaddo dies outcome): a capture leaves no pilot. Is that `swibh` script, and does it need anything from A Pirate's Life?
11. **Shaddo's fallback without A Pirate's Life:** what replaces the S capture beat?
12. **Log events:** does `swibh` add a `hunt.capture` event (or a `captured` role on `hunt.kill`, under a new `v`), and from which signal?
13. **Capture frequency:** with no raised bail chance by default (#89), what does the #84 trial count as "often enough", and who tunes it if it isn't?
14. **L/XL later:** does the contract leave room for the boarding order (a `Decided` with `'boarding'` is already there), so stage 3 needs no contract change?
