#!/usr/bin/env bats
# Tests for the repo's git hooks (.githooks/, turned on by make setup). The pre-commit hook keeps
# commits off main: every change goes through a feature branch and a PR (docs/PROJECT.md, Workflow).

load helpers

setup() {
    setup_sandbox
    mkdir -p "$REPO/.githooks"
    cp "$REPO_ROOT/.githooks/pre-commit" "$REPO/.githooks/"
    git -C "$REPO" config core.hooksPath .githooks
    echo change > "$REPO/docs/notes.md"
    git -C "$REPO" add docs/notes.md
}
teardown() { if [ -n "${SANDBOX:-}" ]; then teardown_sandbox; fi; }

@test "a commit on main is refused, naming the way out" {
    run git -C "$REPO" commit -q -m "on main"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git switch -c feature/"* ]]
    [ "$(git -C "$REPO" rev-list --count main)" -eq 1 ]
}

@test "a commit on a feature branch goes through" {
    git -C "$REPO" switch -q -c feature/thing
    run git -C "$REPO" commit -q -m "on a branch"
    [ "$status" -eq 0 ]
    [ "$(git -C "$REPO" rev-list --count feature/thing)" -eq 2 ]
}

@test "a commit on a detached HEAD goes through, as a rebase makes" {
    git -C "$REPO" switch -q --detach
    run git -C "$REPO" commit -q -m "detached"
    [ "$status" -eq 0 ]
}
