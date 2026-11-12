# A Pirate's Life — Project Context

Read this first. It holds the rules for anyone, and any tool, working on this repo, plus pointers to everything else.

## What this is

An X4: Foundations piracy overhaul: the one pirate mod a player needs, from small-time raider to pirate lord, playable as piracy alone. Base game first, and designed so total conversions such as Star Wars Interworlds can plug in through data profiles. Extension ID: `apirateslife` (see `content.xml`).

## Key decisions

- **SWI build first, 9.x line on hold.** The two lines of the mod are defined in [`GLOSSARY.md`](../GLOSSARY.md).
  - The **SWI build** is the focus: A Pirate's Life for X4 8.00 with S/M capture only (no booty, pirate variants or settings page). It's made for SWI 0.91 HF1, meant to work on any 8.00 setup, and charted on the [map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89).
  - The **9.x line** (latest X4 9.x, vanilla first) waits until the SWI build ships. When SWI moves to 9.x, work moves back to it, with SWI support as a profile or shim.
- **Required DLC:** Tides of Avarice (`ego_dlc_pirate`).
- **Profile-driven core:** no hardcoded vanilla faction, ship, ware or sector IDs in scripts. Universe-specific data lives in profiles; vanilla is the first profile.
- **Use X4's own systems, always:** existing assets, traffic, stations and economy. Use magic (spawning ships, wares or stations, adding credits or cargo, effects with no cause in the universe) only when there's no organic way and fun needs it. See [DESIGN.md, Design pillars](DESIGN.md#design-pillars-and-compatibility-architecture).
- **Capture tiers are data**, not engine classes: S/M/L/XL on vanilla, and SWI adds XXL.
- **XML diff patches only** for library changes; never overwrite base files.
- **UI:**
  - It builds on kuertee's UI Extensions, declared as an optional dependency, and the mod works without it. The SWI build has no UI, so it doesn't declare it.
  - Use SirNukes' Mod Support APIs only where there's no alternative.
  - Why: [research/third-party-ui-apis.md](research/third-party-ui-apis.md).
- **Filenames lowercase** (X4 3.0+ convention; it matters for loose, uncatalogued files). `make test` checks every shipped path.
- **Build order:** the core loop on standard vanilla starts first; custom starts and redemption later.

## The two lines in git

- **`main` is the SWI build.** The 9.x line is parked on the `9.x` branch and the `9.x-parked` tag ([#110](https://github.com/ecarlste/x4-pirates-life-mod/issues/110)). Branch protection locks `9.x` until the SWI build is done.
- **The way back:** once the SWI build is done and SWI moves to 9.x, `main` is tagged `swi-8.00-final` and nothing ships to the 8.00 build after that. One PR from `9.x` brings the 9.x mod back onto `main`, with SWI support on top.
- **SWI build docs:** its spec is an issue, and its decisions live in the [map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89)'s ticket resolutions, and its research is on `research/<name>` branches. `DESIGN.md` and `IMPLEMENTATION_PLAN.md` describe the 9.x line, but their pillars and the key decisions above still apply to the SWI build. Docs of the features the SWI build drops stay on `9.x`.

## Workflow rules

- **Worktrees:** parallel sessions each work in a worktree under `.claude/worktrees/`. `make worktrees` flags any with work that hasn't reached `main`; remove a worktree once it says "can be removed".
- **Every change goes through a feature branch and a PR**, never straight to `main`. Branch names are `feature/…`, `fix/…`, `docs/…` or `spike/…`. Erik and an automated reviewer review every PR. Design discussions happen in chat and build work happens locally in WSL. Commit and push often: GitHub is the hub.
- **PRs are squash-merged:** the PR title becomes the commit title on `main`, and the description becomes its body. Commits inside a branch can be informal.
- **PR titles follow [Conventional Commits](https://www.conventionalcommits.org/):** `type(scope): summary`, at **72 characters or fewer**. It's about where GitHub cuts commit titles off, so `main`'s commit list reads at a glance; don't tighten it. CI checks the title.
  - Types: `feat`, `fix`, `docs`, `test`, `ci`, `build`, `refactor`, `perf`, `style`, `chore`, `revert`. Add `!` for a breaking change.
  - The scope is optional and names the area: `deploy`, `tests`, `tools`, `md`, `plan`, `research`, …
  - The summary uses the terms someone would search for. Anything that doesn't fit goes in the description.
- **PR descriptions** list every change by file or area, say what a reviewer should check closely, and note anything not tested or deliberately left out. A **Test plan** section lists the scenarios added, changed and still pending, or says `Test plan: no change` when a spec or game test changed but the plan didn't.
- **Commits and PRs are authored by Erik only** (`Erik S. Carlsten <ecarlste@gmail.com>`). No co-author trailers, no session links, and no tool attribution or "generated by" lines in commits, PR descriptions or files. The `commit-msg` hook refuses them in commit messages, and the PR-description check (`pr-body.yml`) in PR descriptions.
- **Design sign-off:**
  - Erik signs off every design change, whoever proposes it. Check [`rejected/`](rejected/README.md) before proposing an idea.
  - Propose a change in a "Design proposals" section of the PR description, or in chat. Edit `DESIGN.md` only after Erik has explicitly agreed, and say so in the PR's title or description.
  - Ideas stay in research notes or the plan's "Ideas and maybe" until he signs off. Agreed ideas go into `DESIGN.md`, and get a spec when they're about to be built.
- **Never commit** the unpacked reference files, or game files copied unchanged. Diff patches are fine.
- **When one doc refers to another**, link the exact section (`DESIGN.md#roadmap`), not just the file.

## Where to look

| When you're… | Read |
| --- | --- |
| Running, adding or wiring up tests, or writing test-plan scenarios | [`testing.md`](testing.md) |
| Setting up, deploying, or looking for X4, its game files or profiles | [`environment.md`](environment.md) |
| About to open a PR | [`agents/keeping-docs-in-sync.md`](agents/keeping-docs-in-sync.md) |
| Naming something in the mod's domain | [`GLOSSARY.md`](../GLOSSARY.md) (it defines words only, never decisions) |
| Working on the SWI build | Its [map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89) |
| Working on the 9.x line's design or its agreed work | [`DESIGN.md`](DESIGN.md), the source of truth; [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md), the tracker |
| Building or changing a feature | Its spec, listed in [`specs/README.md`](specs/README.md) |
| About to dig through game files or vanilla behaviour | [`research/README.md`](research/README.md) first; new notes go there, listed in its README |
| About to propose a design idea | [`rejected/README.md`](rejected/README.md) first, then research |
| Rejecting or reopening an idea, or splitting a proposal | [`rejected/README.md`](rejected/README.md), [`agents/domain.md`](agents/domain.md#recording-decisions-in-place-of-adrs) |
| Changing or adding a tool in `tools/` | [`tools/README.md`](../tools/README.md) |

## Current status

- **Focus:** the SWI build, on its [map](https://github.com/ecarlste/x4-pirates-life-mod/issues/89). What's built is in [`specs/README.md`](specs/README.md) and the [test plan](test-plan/README.md).
- **Next:** the map. The 9.x line resumes from the first unticked items in [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) once SWI moves to 9.x.
