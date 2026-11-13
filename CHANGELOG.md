# Changelog

Player-facing changes to A Pirate's Life, newest first. Each release lists any setting whose default changed: updates replace `md/apirateslife_config.xml`, so redo your edits after updating.

## Unreleased

The SWI build's first release, 1.00: S/M capture for X4 8.00, made for Star Wars Interworlds 0.91 HF1.

- Capture operations: hail an S or M ship and choose "Heave to. We're taking your ship."; your wingmen break it to the hold line, then only keep its shields down, with no missiles.
- Bail pressure: the bail chance rises the longer the target spends inside the bail gates, and a pilot who got away stays shaken for a while (fear).
- A mission readout of the bail gates, the pilot's nerve and the crew aboard.
- Claiming an abandoned ship with marines no longer damages its hull or destroys its equipment.
- Settings in one commented config file, `md/apirateslife_config.xml`; bad values are clamped or reset, with a warning in `debuglog.txt`.
