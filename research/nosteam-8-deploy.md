# Deploy and game tests on the 8.00 NoSteam copy

Research for [Deploy and game tests on the 8.00 NoSteam copy](https://github.com/ecarlste/x4-pirates-life-mod/issues/97) (map: [SWI build](https://github.com/ecarlste/x4-pirates-life-mod/issues/89)). Read-only: nothing was deployed and X4 wasn't run. Repos read at `x4-pirates-life-mod` `f407694` and `x4-swi-bounty-hunter` `f8d00da`.

## Short answer

- **Deploy needs no code change.** `deploy.sh`/`deploy.ps1` already take any `X4_PATH`. Point `deploy.config` (and `deploy.config.example`) at `E:\SteamLibrary\steamapps\common\X4 Foundations - 8.00`, and `make deploy` (origin/main) then lands in the 8.00 copy, as the [parking decision](https://github.com/ecarlste/x4-pirates-life-mod/issues/90) needs.
- **The runner needs the bounty hunter runner's NoSteam half ported back:** start `<X4_PATH>\X4_nonsteam.exe` directly with our launch options plus `-personalfolderid <numeric id>`, read the log from that profile folder, and prepare the profile so SWI, `apirateslife` and `apirateslife_tests` are on. Steam launch can go from `main` (the 9.x line keeps it on its branch).
- **The test extension needs `SW Interworlds` as a dependency** so its gamestart loads after SWI's `<replace sel="//gamestarts">`, and a new SWI test gamestart (the vanilla tutorial galaxy and Argon/pirate ships it uses now are unverified under SWI).
- **Sharing:** don't merge the two runners into one file now. Port the pieces into ours, and share only a machine-wide game lock (one X4 per Windows session, and both repos use the same copy). Erik to decide.
- **Biggest open question:** the 8.00 copy is also the series playthrough's install. Deploying APL there probably switches it on in the playthrough's root profile and in the bounty hunter's test profile, since neither `content.xml` mentions `apirateslife` (unverified, see below).

## What's there (verified on disk, 2026-11-11)

- `/mnt/e/SteamLibrary/steamapps/common/X4 Foundations - 8.00/` has `X4.exe` and `X4_nonsteam.exe`. Its `extensions\` holds the 7 DLCs, `starwarsmod_m1` (SWI 0.91 HF1), `starwars_rsp` and `mycu_equipment_tooltips`, with no `apirateslife` yet. `E:\x4-dev\nosteam-8.00\` holds only `X4_nonsteam.exe` (the download's copy).
- Profiles under `C:\Users\ecarl\OneDrive\Documents\Egosoft\X4\`: the root folder (8.00 NoSteam's default, the playthrough's), `28456535` (9.00 Steam), `90000001`/`90000002` (the profile-folder spike) and `90000201` (bounty hunter tests). `90000201\content.xml` switches on `SW Interworlds`, `kuerteeUIExtensionsAndHUD` (not installed), `swibh_tests` and `swibh_trials`. The root `content.xml` has `SW Interworlds` on. Neither has an `apirateslife` entry.
- SWI 0.91 HF1 `ext02/libraries/gamestarts.xml:3` is `<replace sel="//gamestarts">`.

## Comparison

| | Ours (`x4-pirates-life-mod`) | Bounty hunter (`x4-swi-bounty-hunter`) |
| --- | --- | --- |
| Config | `deploy.config`: `X4_PATH` only (`deploy.config.example:14`; runner `Resolve-X4Path`, `tools/run-game-tests.ps1:255-264`) | `test.config`: `X4_PATH`, `X4_EXE`, `X4_PROFILE_ID`, `X4_PROFILE_ROOT`, env vars override (`test.config.example`; `Resolve-Setting`, `tools/run-game-tests.ps1:343-348`); accepts `/mnt/e/...` too (`ConvertFrom-WslPath`, 351-356) |
| Deploy | `deploy.sh`/`deploy.ps1`: mirror `deploy.include` into `<X4_PATH>\extensions\apirateslife`, from origin/main by default (`deploy.sh:33,79`; X4_PATH 52-64; `deploy.ps1:80-87`). `make game-test` deploys the working tree first (`Makefile:54-56`) and leaves it installed | No deploy: the runner copies the test extension in and `extension/swibh/md/*.xml` into it, then removes it (`tools/run-game-tests.ps1:446-450`, finally block) |
| Launch | `steam://rungameid/392160`, then waits for an `X4` process (`tools/run-game-tests.ps1:321-328`). Launch options come from Steam. `-GameExe` starts an exe with **no arguments** (317-320), for the fake-game tests | `Start-Process <X4_PATH>\X4_nonsteam.exe -ArgumentList "-skipintro -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid $ProfileId"` (440, 459) |
| Profile | None: `Resolve-LogPath` takes whichever numbered profile folder has the newest `debuglog.txt` (267-274) | Numeric `X4_PROFILE_ID` (default `90000201`, refused if not numeric, 398-399); log is `<profile>\debuglog.txt` (400-402). `-PrepareProfile` copies the root `content.xml`/`config.xml` in (read-only on the root) and switches SWI and the test extension on (418-426, `Enable-Extensions` 366-380); without it, refuses to run if SWI or the test extension is off (427-437) |
| Preflight | Mod deployed (299-301); no `X4` process running (302-305) | Exe exists, SWI installed (407-410); no process of **its own exe name** running (411-414) |
| Launch timeout | Waits for the process (120 s) | Fails if no `debuglog.txt` within 60 s ("did -personalfolderid take?", 483-485) |
| Run timeout | 900 s | 1200 s (SWI loads slower) |
| Test gamestart | `tests/game/apirateslife_tests/libraries/gamestarts.xml`: vanilla tutorial wharf galaxy, `ship_arg_s_scout_01_a_macro`; the test MD uses `faction.argon`, `faction.loanshark` and vanilla `arg`/`par`/`pir` ship macros. `content.xml` depends on `apirateslife` and `ego_dlc_pirate` only | `tests/game/swibh_tests/libraries/gamestarts.xml`: SWI's `sws_galaxy_macro` showcase sector, SWI `fortitude_macro`, group 9; `content.xml` depends on `version 800` and `SW Interworlds`, with a comment on why (SWI's replace) |
| Extras | `-Commit/-Branch/-Dirty` and the PR report (`make game-test-report`); SETA-drop count | `-Manual` (existing-save T12), INFO/VERDICT/HOOK lines, T12 verdict, copies the log to `tests/game/debuglog.txt` for `tools/log/game-check.ts` |

The parser, JUnit/Markdown reports, phases and `Read-SharedFile` are the same code with a different marker (`[apirateslife-test]` vs `[swibh-test]`).

## What our deploy and runner need

On `main` (the SWI build), after the PRs [X4 profile folders via NoSteam](https://github.com/ecarlste/x4-pirates-life-mod/pull/84) and [X4 8.00 NoSteam copy for SWI](https://github.com/ecarlste/x4-pirates-life-mod/pull/85) merge and `9.x` is cut:

1. **Config.** `deploy.config.example`: `X4_PATH` to the 8.00 copy, plus `X4_EXE="X4_nonsteam.exe"`, `X4_PROFILE_ID`, optional `X4_PROFILE_ROOT`, with the same names and rules as the bounty hunter's `test.config` (env overrides; Windows or `/mnt/` paths). Erik edits his own `deploy.config` too. One file serves deploy and runner, as now.
2. **Deploy scripts:** no change for the path. Optional: refuse to deploy while X4 is running (files in use). Not needed for the decision.
3. **Runner launch:** drop the Steam branch (or keep it only when `X4_EXE` is empty, unverified if worth it), start `<X4_PATH>\<X4_EXE>` with `-skipintro -debug all -logfile debuglog.txt -scriptlogfiles -personalfolderid <id>`, working dir `X4_PATH`. Keep `-GameExe` for the fake game, but pass it the same arguments.
4. **Runner profile:** take the log path from the profile id and delete `Resolve-LogPath`'s guessing (it can already pick `90000201`'s log for a 9.00 Steam run when the bounty hunter ran last). Port `-PrepareProfile`, switching on `SW Interworlds`, `apirateslife` and `apirateslife_tests`, and the refuse-if-off checks. Port the "no log within N s" launch check.
5. **Runner preflight:** check no `X4` **and** no `X4_nonsteam` process is running (one game per Windows session, see the spike in [X4 profile folders via NoSteam](https://github.com/ecarlste/x4-pirates-life-mod/pull/84)); the bounty hunter runner has the same gap. Raise the default timeout to about 1200 s.
6. **Test extension:** `content.xml` adds `<dependency version="800"/>` and `<dependency id="SW Interworlds" .../>` so `apirateslife_test` survives SWI's `<replace sel="//gamestarts">`. Whether `apirateslife` itself should depend on SWI is the spec's call.
7. **SWI test gamestart:** new location, ship and factions, likely the bounty hunter's quiet `sws_galaxy_macro` start, with group 9 (SWI replaces vanilla's groups). The tests' factions and macros (`argon`, `loanshark`, vanilla ship macros) need SWI equivalents; that's part of porting the scenarios with the spec, not this ticket. Unverified whether the vanilla tutorial galaxy and vanilla ships still load under SWI.
8. **Tests for the scripts:** `tests/RunGameTests.Tests.ps1` and `tests/GameTests.Tests.ps1` (fake game via `-GameExe`, `-LogPath`) need cases for the arguments, the profile path, `-PrepareProfile` and the two process names. `deploy.config.example` changes need nothing in `deploy.bats`/`Deploy*.Tests.ps1` unless step 2 is done.
9. **Docs:** `PROJECT.md` Workflow (`make deploy` targets the 8.00 copy; `make game-test` no longer uses Steam launch options; first run `ARGS=-PrepareProfile`) and Paths (the test profile id); `docs/research/automated-game-testing.md`.

The 9.x branch keeps today's Steam runner. It's locked, so nothing there changes now. When it comes back, the runner must handle both (the config already allows it).

## Should the two repos share the runner?

**Recommendation: not as one file now.** Port the NoSteam and profile pieces into ours (they're the bounty hunter's adaptation of our code, so this is copying back), and keep two runners.

- About 60% is the same (parser, reports, polling, cleanup), but each repo has real extras: our PR report and git state, their `-Manual`, T12, HOOK/VERDICT lines and log check. Their tooling also differs: Pester and bats here, `GameTests.Check.ps1` and TypeScript there. A shared module would need a home, versioning and both repos' test suites, which is too much before the SWI build ships.
- **What must be shared is the game lock.** One X4 runs per Windows session (named mutex `EGOSOFT_X4_INSTANCE`, from [X4 profile folders via NoSteam](https://github.com/ecarlste/x4-pirates-life-mod/pull/84)), and both repos now use the same 8.00 copy, so a run from one repo can collide with a run, deploy or play session from the other. The [shared game-test queue](https://github.com/ecarlste/x4-pirates-life-mod/pull/84) proposal should use one machine-wide lock file both runners take (for example under `%LOCALAPPDATA%`), and it should also cover our deploy, which writes into that copy. This is a convention plus a few lines in each runner.
- Revisit extracting a shared module after launch, if the two keep drifting the same way.

## Open questions for Erik

1. **APL in the shared 8.00 copy.** `make deploy` and `make game-test` leave `apirateslife` installed there. Neither the root (playthrough) profile nor `90000201` lists it in `content.xml`, and our `content.xml` says `enabled="true"`. So it probably loads in the series playthrough and in the bounty hunter's game tests, which are meant to run on bare SWI (`mods.md`). This is unverified: how X4 treats a new extension with no profile entry wasn't tested. Options: add `apirateslife` with `enabled="false"` to the root profile's `content.xml`; have the bounty hunter's `-PrepareProfile` switch it off; or deploy APL to a separate test-only 8.00 copy (about 30+ GB).
2. **Which test profile:** share `90000201` with the bounty hunter, or give APL its own (for example `90000301`)? Its own keeps each repo's extension switches apart. Sharing means one profile to keep in step with the playthrough's mods.
3. **Keep the Steam launch path on `main`** (unused while `main` is 8.00), or drop it and let the 9.x branch carry it?
4. **The shared lock**: adopt the queue proposal from [X4 profile folders via NoSteam](https://github.com/ecarlste/x4-pirates-life-mod/pull/84) for both repos, including deploys?

## Not verified

- That X4 switches on a newly installed extension with no `content.xml` entry (open question 1).
- That the current vanilla test gamestart and ship macros load under SWI 0.91 HF1 (SWI's `ext/assets/cutscenecore/startmenu_sw_*.xml` reference the tutorial galaxy, which suggests the map is still there).
- Load order of `apirateslife_tests` vs SWI without the dependency. It's added anyway, as the bounty hunter does.
- Whether a Steam `X4.exe` and `X4_nonsteam.exe` block each other ([X4 profile folders via NoSteam](https://github.com/ecarlste/x4-pirates-life-mod/pull/84): most likely yes).
