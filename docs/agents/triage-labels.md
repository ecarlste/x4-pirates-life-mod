# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the "Label in our tracker" column to match whatever vocabulary you actually use.

## Ideas

One more label sits outside the triage roles: [`idea`](https://github.com/ecarlste/x4-pirates-life-mod/issues?q=is%3Aopen+label%3Aidea), for an idea Erik hasn't agreed to build. File a new idea as an issue titled `Idea: …` with this label, and no triage label.

- **Erik wants to decide on it:** swap `idea` for `needs-triage`.
- **Erik agrees to it:** drop `idea`; the agreed design goes into `DESIGN.md` ([domain.md](domain.md#recording-decisions-in-place-of-adrs)), and the issue becomes the work's ticket or links the one that does.
- **Erik rejects it:** see [rejected/README.md](../rejected/README.md#rejecting-an-idea).
