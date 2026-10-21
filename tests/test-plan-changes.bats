#!/usr/bin/env bats
# Tests for tools/check-test-plan-changes.py: on a PR, a changed spec or game test needs a
# changed feature file, unless the PR description says "Test plan: no change". Each test builds a
# small git repo with a main branch and a PR branch on top.

setup() {
    command -v python3 >/dev/null || skip "python3 is not installed"
    CHECK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/tools/check-test-plan-changes.py"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q -b main "$REPO"
    cd "$REPO" || return 1
    mkdir -p docs/specs tests/game/features tests/game/apirateslife_tests/md
    echo 'Scenarios: [x](../../tests/game/features/thing.feature)' > docs/specs/thing.md
    echo 'Feature: Thing' > tests/game/features/thing.feature
    echo 'Feature: Other' > tests/game/features/other.feature
    echo '<mdscript/>' > tests/game/apirateslife_tests/md/tests.xml
    echo '# Specs' > docs/specs/README.md
    commit "main"
    git checkout -q -b pr
    unset PR_BODY
}

commit() { git add -A && git commit -q -m "$1"; }

# change <file>...: appends a line to each file and commits
change() {
    for file in "$@"; do echo "changed" >> "$file"; done
    commit "change $*"
}

check() { run python3 "$CHECK" main; }

@test "passes when nothing relevant changed" {
    echo 'notes' > notes.md && commit "notes"
    check
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test plan: OK"* ]]
}

@test "passes when a spec and its feature file both changed" {
    change docs/specs/thing.md tests/game/features/thing.feature
    check
    [ "$status" -eq 0 ]
}

@test "fails when a spec changed but its feature file didn't" {
    change docs/specs/thing.md
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"docs/specs/thing.md changed, but tests/game/features/thing.feature didn't"* ]]
}

@test "a different feature file changing doesn't count for the spec" {
    change docs/specs/thing.md tests/game/features/other.feature
    check
    [ "$status" -eq 1 ]
}

@test "fails when the game tests changed but no feature file did" {
    change tests/game/apirateslife_tests/md/tests.xml
    check
    [ "$status" -eq 1 ]
    [[ "$output" == *"the game tests"* ]]
}

@test "passes when the game tests and a feature file both changed" {
    change tests/game/apirateslife_tests/md/tests.xml tests/game/features/other.feature
    check
    [ "$status" -eq 0 ]
}

@test "the specs README doesn't count as a spec" {
    change docs/specs/README.md
    check
    [ "$status" -eq 0 ]
}

@test "'Test plan: no change' in the PR description lets it pass, listing what changed" {
    change docs/specs/thing.md
    PR_BODY=$'Fix a typo.\n\nTest plan: no change' check
    [ "$status" -eq 0 ]
    [[ "$output" == *"no change (as the PR description says)"* ]]
    [[ "$output" == *"docs/specs/thing.md changed"* ]]
}

@test "the opt-out ignores case" {
    change docs/specs/thing.md
    PR_BODY='test plan: No Change' check
    [ "$status" -eq 0 ]
}
