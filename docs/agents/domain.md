# Domain Docs

How the engineering skills should read and write this repo's domain documentation. This repo has no ADRs: decisions live in its design docs, under the sign-off rules in `docs/PROJECT.md` (Workflow).

## Before exploring, read these

- **`docs/DESIGN.md`**: the agreed design, the source of truth. Read the sections that touch your area.
- **`docs/specs/`**: one spec per agreed feature; `docs/specs/README.md` lists them with their status.
- **`docs/research/README.md`**: what we know about vanilla X4 and SWI, and ideas still being worked on. Check it before digging through game files.
- **`docs/rejected/README.md`**: ideas Erik rejected. Check it before proposing anything.
- **`GLOSSARY.md`** at the repo root, if it exists.

## Vocabulary

Use the terms the design docs use (booty, pirated ship, capture operation, hold line, profile, …), in issue titles, test names and proposals alike; don't drift to synonyms. `/domain-modeling` may create `GLOSSARY.md` at the repo root, lazily, to pin down a term when it gets resolved. The glossary only defines words: it never records a decision.

## Recording decisions (in place of ADRs)

Where a skill would write an ADR:

- **Design decisions** go into `docs/DESIGN.md`, and only after Erik has explicitly agreed, in chat or on the PR. Until then they're "Design proposals" in the PR description, or stay in a research note.
- **Feature-level decisions** go into that feature's spec in `docs/specs/`.
- **Rejected ideas** move to `docs/rejected/` (see its README).
- **Wayfinder tickets** hold their decision in the resolution comment. If it changes the design, it also goes into `DESIGN.md` on sign-off, and the ticket links that PR.

## Flag conflicts

If your output contradicts `DESIGN.md`, a spec, a "Key decisions" entry in `docs/PROJECT.md`, or a rejected idea, say so explicitly rather than silently overriding:

> _Contradicts DESIGN.md#roadmap (9.x only), but worth reopening because…_
