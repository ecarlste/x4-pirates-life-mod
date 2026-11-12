# Keeping docs in sync

Check this before opening a PR. When one of these happens, update the matching docs in the same PR.

Some updates are left out of the table because a check fails when they're missed. Those are test filters, feature-file tags, `make test-plan`, scenarios for a changed spec, doc paths, and a row in the `tools/README.md` table for each file. See [testing.md](../testing.md#wiring-a-test-in).

| When | Update |
| --- | --- |
| We agree to new work, however small or far off | Add it to `IMPLEMENTATION_PLAN.md`, linking the PR that adds it; if it carries its design, start it with **Not built:** |
| A PR is opened for a plan item | Link the PR from the item |
| A PR finishes a plan item | Tick it off and drop any **Not built:** label; if it has a spec, mark the spec Done in the spec and in `docs/specs/README.md` |
| A feature's design is agreed | Write a spec from `docs/specs/_template.md`, add it to `docs/specs/README.md`, link it from the plan item; write its scenarios in `tests/game/features/` (tagged `@pending`) |
| Building a feature changes its design | Update its spec |
| Erik signs off a design choice or change | `DESIGN.md`, in the same PR as the work or its own `docs/` PR |
| Research or other work suggests a design change not yet signed off | A "Design proposals" list in the PR description; not `DESIGN.md` |
| Erik rejects a design idea | Move it into `docs/rejected/` ([how](../rejected/README.md#rejecting-an-idea)) |
| Erik approves reopening a rejected idea | Move it back into research ([how](../rejected/README.md#reopening-a-rejected-idea)) |
| A research note is added or changes status | Its row in `docs/research/README.md` |
| A research spike finishes | Notes in `docs/research/`; update the plan's order and items to match |
| A key decision changes (target version, DLC, architecture) | "Key decisions" in `docs/PROJECT.md`, and `DESIGN.md` |
| A setup step, command, or path changes | `docs/environment.md`, or `docs/testing.md` for test commands |
| A script changes | Its tests in `tests/`, and its entry in `tools/README.md` for anything in `tools/` |
| A new top-level mod folder is added (`md/`, `aiscripts/`, …) | `deploy.include`, or it won't ship |
| `deploy.config` gains or changes a setting | `deploy.config.example` |
