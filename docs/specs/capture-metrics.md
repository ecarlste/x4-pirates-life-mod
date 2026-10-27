# Spec: Capture metrics

Plan item: Phase 2, slice 1, "Capture metrics" · Status: Agreed

## Goal

Every capture attempt the player makes, with a capture operation or by just shooting, leaves one summary line in `debuglog.txt` when it ends: what the target was, who attacked it, how long each stage took, and how it ended. A `tools/` script turns any number of `debuglog.txt` files into one CSV, so we can see how long captures take for each kind of ship and each pirate gang over time. The numbers set the booty level thresholds ([booty research note](../research/booty.md#capture-times)).

## Context

- Agreed in chat (2026-10-26) as the plan item above, after the booty design ([DESIGN.md, Booty and pirate standing](../DESIGN.md#booty-and-pirate-standing)).
- Before this, the log has the pieces but not a whole capture: `capture: started` and `capture: ended` (`md/apirateslife_capture.xml`), `bail check` and `bailed` (`md/apirateslife_bail.xml`), `pilot bail` (`md/notifications.xml`), with no target class, crew, pilot skill or attacker list, and nothing for a plain attack.
- Vanilla's bail flow (`base/md/notifications.xml`, `PlayerOwnedShipAttacks`): the gates are shields < 20% (or no shields), hull < 75%, not docked; then at most one evaluated check every 30 s per target pilot. Our `AdjustEjectChance` runs only for evaluated checks, so every call is a check; every `Bailed` signal is a success.

## Design

**One script, `md/apirateslife_metrics.xml`,** that only watches; it changes nothing in the game.

- **What's tracked:** a record per target in `global.$APiratesLife_CaptureMetrics`, a list (not a table keyed by ship, so destroyed ships can't drop out of it unseen).
  - **Operations:** a record starts when an operation starts (a new `md.APiratesLife_Capture.Started` signal, like `Ended`), and ends with the operation's outcome.
  - **Plain attacks:** a record starts on the first hit or bail check on a ship that could bail to the player (operational ship with a pilot, capturable, not player-owned or ownerless, not a drone), when the attacker is the ship the player flies or one of its direct subordinates. Hits by the rest of the player's fleet don't start records, so a big fleet battle doesn't fill the list; once a record runs, every player-owned attacker is counted.
  - **A plain attack ends** as `abandoned` (ownerless), `captured` (player-owned), `destroyed`, or `dropped` after 120 s with no hit and no check.
  - A plain attack that becomes an operation keeps its record and its start time, and becomes an operation record.
- **What's recorded:** at the start, the target's name, ID code, macro, size, ship type, owner, value in credits, crew and crew capacity, pilot skill, combined crew skill and morale (the pilot has left by the end). Then the wingmen, every attacker with its macro, size and hit count, hits by the ship the player flew, the time the gates were first open (checked every second), the first check, the number of checks and each one's chance, successes, crew bailed, whether the pilot bailed, the total time and the outcome. Times are whole seconds of game time from the start.
- **The summary line:** `[apirateslife] capture metrics: v=1 | key=value | …`. One line per attempt, `key=value` fields split by ` | `, so the tool doesn't depend on field order and new fields don't break old logs; `v` changes only if a field's meaning does. The same record goes out as the `md.APiratesLife_Metrics.Summary` signal, for the game tests and later features.
- **The bail hook** signals each check to the metrics script (`md.APiratesLife_Metrics.BailChecked`) instead of the metrics code living in the hook.
- **The CSV tool,** `tools/capture_metrics.py`: reads `debuglog.txt` files (or folders of them), writes one row per summary line with the source file, the known fields in a fixed order, then any unknown fields. Strips enum prefixes (`shiptype.fighter` → `fighter`). Standard library only.
- **Always on,** no setting: it costs one list scan per hit by the player's own wing, and a line per attempt.

Not in v1: cargo, damage to the player's side, missiles fired. Add fields when a question needs them.

## Tasks

- [ ] `md/apirateslife_metrics.xml`, the `Started` signal in `md/apirateslife_capture.xml`, the `BailChecked` signal in `md/apirateslife_bail.xml`
- [ ] Game tests: an operation and a plain attack each end in a summary with the right fields
- [ ] `tools/capture_metrics.py` with unit tests in `tests/python/`, listed in `tools/README.md`

## Done when

The scenarios in [`tests/game/features/capture-metrics.feature`](../../tests/game/features/capture-metrics.feature) pass, and a real capture in Erik's save leaves a summary line the tool turns into a CSV row.

## Open questions

- How enums (`.type`, `.class`) print in `debug_text`; the tool strips a `prefix.` either way.
- Whether `.value` counts hull damage (also a booty check); the summary logs it at the start, before any damage.
