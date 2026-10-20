# Research notes

What we've learned about how vanilla X4 works, for designing and building against it. Notes can be WIP; say so in the status. When a note changes the design, list the changes for the living design doc in the PR (see [PROJECT.md, Keeping docs in sync](../PROJECT.md#keeping-docs-in-sync)).

| Note | Covers | Status |
| --- | --- | --- |
| [third-party-ui-apis.md](third-party-ui-apis.md) | SirNukes vs. kuertee's UI Extensions on 9.0, how SWI builds its UI, the vanilla Lua ↔ MD bridge, approach for our settings page | Done for the settings decision |
| [prior-art-better-piracy.md](prior-art-better-piracy.md) | Better Piracy (original, Reforged, Reborn for 9.x): every feature and how it's built, config, bugs, how we'd do better; related mods | Done for Better Piracy Reborn; related mods unstudied |
| [automated-game-testing.md](automated-game-testing.md) | Running regression tests in the real game: autostarting a test gamestart from Lua, deterministic bail and claim scenarios in MD, quitting and time warp from MD, a log-reading runner, CI fit, UI testing options | WIP: proof of concept built, not yet run in game |
| [spike-1-bailing-boarding.md](spike-1-bailing-boarding.md) | Bail checks, eject chance, NPC-vs-NPC bails, capture hooks; boarding to come | WIP: bailing mostly mapped |
| [pirate-refitting.md](pirate-refitting.md) | Getting weapons, turrets and shields onto captured ships without legit factions: licence and relation gates, which pirate stations can fit S/M gear, blueprint routes (pirate reps, data leaks, agent theft), routes by career stage, MD building blocks (`apply_loadout`, `generate_loadout`, blueprint drops), design ideas incl. trading booty to a target's pirate enemies for "pirated" versions of its gear | WIP: game files mapped, nothing verified in game |
