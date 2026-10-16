# Spec: <Feature name>

<!-- Copy to docs/specs/<feature-slug>.md once the design is agreed. Delete these comments as you fill it in.
     Write it so one person + AI session can implement the whole thing from this file alone:
     anything the session would otherwise have to rediscover belongs here. -->

| | |
| --- | --- |
| Status | Draft / Agreed / In progress / Done |
| Plan item | [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md), Phase N, item |
| Design | DESIGN.md sections this implements |
| Branch / PR | `feature/<slug>` / PR link |

## Session brief

<!-- The first thing an implementing session reads. Keep it short. -->

- **Goal:** one or two sentences on what the player can do when this is done.
- **Read first:** the design sections, research notes and vanilla files (paths under `/mnt/e/x4-dev/reference/x4-9.xx/`) needed to start.
- **Touch:** files and folders expected to change or be created.
- **Don't touch:** anything off-limits or owned by another feature.
- **Loop:** `make deploy-local`, restart X4, load `<showcase save>`, check `debuglog.txt`.

## Player-facing behavior

What the player sees and does, step by step, including failure cases ("the target has an escort", "no free crew for a prize crew").

## Scope

**In:** what this spec delivers.

**Out:** what it deliberately leaves for later, with the plan item each one belongs to.

## Background

What we learned about vanilla that this builds on: the cues, orders and library values involved, with file paths and line references. Link the research notes rather than repeating them.

## Design

The low-level design. Cover whichever of these apply:

- **MD scripts:** cues, events listened to, signals raised (names and parameters).
- **AI scripts / orders:** order ids, parameters shown in the order menu, the state machine.
- **Library patches:** each `<diff>` with its selector and why it is tolerant.
- **Profile data:** what moves into the vanilla profile instead of being hardcoded (factions, macros, tiers).
- **UI:** menus, hotkeys, notifications, and which framework (UI Extensions, SirNukes' APIs).
- **Tunables:** values that become difficulty sliders, with defaults and ranges.
- **Signals for other mods:** additions to the integration contract.

## Compatibility checklist

- [ ] No hardcoded vanilla faction, ship, ware or sector ids in scripts (profile data instead)
- [ ] Library changes are diff patches with tolerant selectors
- [ ] UI builds on UI Extensions or SirNukes' APIs; no replaced Lua files
- [ ] Lowercase filenames
- [ ] Safe to add to and remove from an existing save, or documented if not

## Tasks

<!-- Ordered so each task leaves the mod working and can be checked on its own. Tick them off as you go. -->

- [ ] 1. ...
- [ ] 2. ...

## Verification

- **In game:** the steps to reproduce each behavior above, and what a pass looks like.
- **Logs:** lines to expect (and not expect) in `debuglog.txt`.
- **Showcase save:** which save to record for this feature, and its starting state.
- **Scripts:** tests to add if this changes repo tooling (`make test`).

## Done when

- [ ] Every task and verification step above passes
- [ ] Plan item ticked off and this spec marked Done
- [ ] Design doc updated with anything that changed during the build
- [ ] Showcase save recorded

## Open questions and risks

Anything still undecided, and what to do if a risk comes true (for example, "if the engine won't let wingmen claim bails, fall back to ...").
