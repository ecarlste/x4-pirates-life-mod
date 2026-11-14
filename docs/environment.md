# Environment

Setting up, deploying, and where the game, its files and its profiles live on Erik's machine.

## Setup

Run `make setup` once. It does three things:

- Creates `deploy.config` from `deploy.config.example`, in the main checkout only: a worktree uses the main checkout's ([Settings](#settings)). When it gains or changes a setting, update `deploy.config.example` too.
- Turns on the git hooks in `.githooks/`. The pre-commit hook refuses commits on `main`, and the commit-msg hook refuses attribution lines (co-author trailers, session links, "Generated with/by" lines).
- Installs the TypeScript tools' packages with `npm install`.

## Settings

The deploy, the game tests and the diff-patch check read their settings (`X4_PATH`, `X4_EXE`, `X4_PROFILE_ID`, `X4_PROFILE_ROOT`, `X4_UNPACKED`, `SWI_UNPACKED`; what each is for is in `deploy.config.example`) in this order, setting by setting:

1. **An environment variable** of the same name, e.g. `X4_PATH='E:\…\X4 Foundations' make game-test`. `make game-test` hands them on to the Windows runner.
2. **The checkout's own `deploy.config`.**
3. **The main checkout's `deploy.config`**, for a worktree. It's the one source for every checkout: since `main` is the SWI build, it points at the 8.00 copy. A worktree needs no `deploy.config` of its own; add one only to override a setting there, e.g. `X4_PATH` for 9.00 on the 9.x line.

In each file the last line naming a setting wins, and an empty value (`X4_PROFILE_ROOT=`) counts as not set, so it falls through to the next source rather than blanking one. `tools/deploy-config.sh`, `tools/deploy-config.ps1` and `tools/diff-patches/config.ts` implement this order, one per language.

## Deploying

- **"Deploy" means `make deploy`:** it fetches the latest `origin/main` and syncs it into `extensions/apirateslife`, deleting files that left the mod. It deploys `main` whichever branch is checked out.
- **Other ways to deploy:**
  - `make deploy-local` syncs the working tree, uncommitted changes included, for in-game testing before a PR.
  - `./deploy.sh --ref <branch>` deploys a pushed branch.
  - `make deploy-dry-run` previews a deploy.
  - In PowerShell: `.\deploy.ps1` (`-WorkingTree`, `-Ref <branch>`, `-DryRun`).
- **Settings for a test deploy:** `--set NAME=VALUE` (PowerShell `-Set`) overrides a value from `md/apirateslife_config.xml` in the deployed copy only. For example: `make deploy-local ARGS="--set CaptureFloorHull=20"`. Repeat it or use commas; unknown names fail. The next deploy without it restores the committed values.
- **The game lock:** a deploy waits while another deploy or game run holds `<X4_PATH>\game.lock`, whether it comes from this repo or the bounty hunter's ([how it works](../tools/README.md#the-game-lock)). `X4_GAME_LOCK_WAIT=0` refuses at once instead of waiting. A crashed run's lock gets taken over after 60 s.
- **What ships:** only the paths in `deploy.include`, so add a new top-level mod folder there. Restart X4 after deploying.

## Paths (Erik's machine)

| What | Path |
| --- | --- |
| Repo (WSL, Ubuntu 26.04) | `~/workspace/x4-pirates-life-mod` |
| Bounty hunter repo, the model for the TypeScript tooling (WSL) | `~/workspace/x4-swi-bounty-hunter` |
| X4 install | `E:\SteamLibrary\steamapps\common\X4 Foundations` → `/mnt/e/SteamLibrary/steamapps/common/X4 Foundations` |
| Deployed mod | `.../X4 Foundations/extensions/apirateslife` |
| Unpacked reference data (not in git) | `E:\x4-dev\reference\x4-9.xx\` → `/mnt/e/x4-dev/reference/x4-9.xx/`; other mods for study in `E:\x4-dev\reference\mods\` |
| Unpacked 8.00 and SWI (the diff-patch check's `X4_UNPACKED`, `SWI_UNPACKED`) | `E:\x4-dev\reference\x4-8.00\base\` → `/mnt/e/x4-dev/reference/x4-8.00/base/` (DLC folders next to it) and `E:\x4-dev\reference\mods\swi-0.91hf1\` → `/mnt/e/x4-dev/reference/mods/swi-0.91hf1/` (`ext02\`, `ext\`). In the shell, type the WSL form: reading `X4_UNPACKED` from `deploy.config` strips its backslashes |
| Steam Workshop mods | X4 installs them into the game's own `extensions\` folder, not Steam's workshop folder, and syncs them when the game starts |
| X4 9.00 profile (saves, config, `debuglog.txt`) | Steam profile: `C:\Users\ecarl\OneDrive\Documents\Egosoft\X4\28456535\`, a folder named after the Steam account ID. The in-game menu shows save slots 1–10 |
| X4 9.00 launch options (Steam) | `-skipintro -debug all -logfile debuglog.txt -scriptlogfiles` |
| X4 8.00 HF4 copy for SWI (NoSteam) | `E:\SteamLibrary\steamapps\common\X4 Foundations - 8.00`, started by the `X4_8.00` desktop shortcut (`X4_nonsteam.exe` with the launch options above). Its `extensions\` has only the DLCs and SWI 0.90 (`starwarsmod_m1`); other mods get installed by hand. The NoSteam download is kept in `E:\x4-dev\nosteam-8.00\` (9.00's is in `nosteam-9.00\`) |
| X4 8.00 game-test profile | `…\Egosoft\X4\90000301\`, made by `make game-test RUNNER_ARGS=-PrepareProfile`. Its `debuglog.txt` is the game tests' log. Runs never touch the playthrough's profile or the bounty hunter's (`90000201`) |
| X4 8.00 profile | The root folder `…\Egosoft\X4\`, which NoSteam uses by default. The old 7.60 profile and saves (they don't load in 8.00) are backed up in `E:\x4-dev\backups\x4-root-profile-7.60-2026-10-30\` |

The main checkout's `deploy.config` sets `X4_PATH` (the 8.00 copy), `X4_EXE`, `X4_PROFILE_ID` and `X4_PROFILE_ROOT` for the game tests ([Settings](#settings)).

`-personalfolderid` gives a separate profile only with a numeric ID; the 2026-10-28 NoSteam spike made `…\Egosoft\X4\90000001\`. With a full path or a plain folder name (tested 2026-10-17/18), X4 falls back to the root folder.

When X4 updates to a new version, re-unpack the game files into a new `x4-<version>` folder and update this table.
