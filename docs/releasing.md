# Releasing

How a version of the mod gets from `main` to testers, as a GitHub Release, and later to players at large. The spec is the SWI build's [Release packaging, versions and docs](https://github.com/ecarlste/x4-pirates-life-mod/issues/109) section.

## Versions

- 1.00, then 1.01, 1.02 and so on; the 9.x line starts at 2.00.
- `content.xml` is the only place the version and date are set: `version="100"` is 1.00, `version="101"` is 1.01.
- The tag is `v<version>`, on the `main` commit that sets it.

## The flow

1. **A `chore(release): <version>` PR** bumps the version and date in `content.xml` and turns `CHANGELOG.md`'s `## Unreleased` into `## <version> - <date>`, listing any default that changed (updates replace the config file). Nothing else goes in it.
2. **After it merges,** tag that commit: `git fetch origin && git tag v<version> origin/main && git push origin v<version>`.
3. **Build the zip:** `make release TAG=v<version>`. It runs every test suite in a clean checkout of the tag first, and writes `dist/apirateslife-<version>.zip` and `dist/apirateslife-<version>-checklist.md`.
4. **Check the checklist** in game: every `@manual` and `@pending` scenario, including installing from the zip itself. Run the release sessions too, `make game-test RUNNER_ARGS=-Release` on the tag: they play the release scenarios that need a save made without the mod, or loaded without it ([testing.md, Release sessions](testing.md#release-sessions)).
5. **Publish it** as a GitHub Release: `gh release create v<version> dist/apirateslife-<version>.zip --notes-file <notes>`. The notes are the version's changelog section, under a header that says it's a release for testers, asks for feedback in [GitHub Issues](https://github.com/ecarlste/x4-pirates-life-mod/issues), says it's an unofficial add-on for SWI 0.91 on X4 8.00, and credits the SWI team and Enhanced Bailing's author (wording in `release/README.txt` and `release/CREDITS.txt`).

Until the public release, GitHub Releases are for testers only, and viewers of the bounty hunter video series who install one count as testers. The **public release** puts the same zip on Nexus, and maybe Steam Workshop, once Erik judges the testers' feedback enough and the issues it found are fixed ([#179](https://github.com/ecarlste/x4-pirates-life-mod/issues/179)). Before it, ask the SWI team (Shuulo and Mik, in `#modding-and-patches` on the SWI Discord) as a courtesy; don't block on silence, and drop the build if they say no ([SWI team's terms](https://github.com/ecarlste/x4-pirates-life-mod/issues/93)).

`make release` with no `TAG` builds the latest `origin/main` the same way, to try the zip before tagging; it doesn't need the changelog section yet.

## What `make release` checks

`tools/release.sh` ([tools/README.md](../tools/README.md)) refuses to build when:

- any test suite fails on that commit (`tests/run.sh --all`);
- `v<version>` already exists on a different commit (bump the version, or build the tag);
- a given tag's `content.xml` holds another version;
- a given tag's `CHANGELOG.md` has no `## <version>` section, or `LICENSE`, `CHANGELOG.md`, `release/README.txt` or `release/CREDITS.txt` is missing.

## What the zip holds

One top-level `apirateslife` folder, as loose files (no catalog):

- the `deploy.include` paths, as `make deploy` ships them;
- `LICENSE` (MIT) and `CHANGELOG.md`;
- `README.txt` and `CREDITS.txt`, from `release/`.

`release/README.txt` is the player's guide. Its Settings and Tuning sections list every value in `md/apirateslife_config.xml`, with its default, under the same banner; `tools/check-readme-settings.ts` fails `make test` when they drift apart.
