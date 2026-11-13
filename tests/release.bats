#!/usr/bin/env bats
# Tests for tools/release.sh (make release). Run with tests/run.sh (or `make test`).
# The test suite the release runs is a stub (RELEASE_TEST), so these test the script, not the mod.

load helpers

setup() {
    setup_sandbox
    cp "$REPO_ROOT/tools/release.sh" "$REPO_ROOT/tools/test_plan_docs.py" "$REPO_ROOT/tools/check_test_plan.py" "$REPO/tools/"
    # What the release checklist reads: one hand-checked scenario, an empty harness and runner
    mkdir -p "$REPO/tests/game/features" "$REPO/tests/game/apirateslife_tests/md"
    printf 'Feature: Release\n\n  @manual\n  Scenario: The zip installs\n    Given the zip\n' > "$REPO/tests/game/features/release.feature"
    echo '<mdscript/>' > "$REPO/tests/game/apirateslife_tests/md/apirateslife_tests.xml"
    : > "$REPO/tools/run-game-tests.ps1"
    # The files only the zip ships
    echo 'MIT License' > "$REPO/LICENSE"
    printf '# Changelog\n\n## 1.00 - 2026-11-20\n\n- First release\n' > "$REPO/CHANGELOG.md"
    mkdir -p "$REPO/release"
    echo 'player readme' > "$REPO/release/README.txt"
    echo 'credits' > "$REPO/release/CREDITS.txt"
    commit_all "release files"
    git -C "$REPO" push -q
    export RELEASE_TEST=true
    ZIP="$REPO/dist/testmod-1.00.zip"
}
teardown() { teardown_sandbox; }

release() {
    run "$REPO/tools/release.sh" "$@"
}

# Lists the zip's entries, files only, sorted
zip_files() {
    python3 -c 'import sys, zipfile; print("\n".join(sorted(n for n in zipfile.ZipFile(sys.argv[1]).namelist() if not n.endswith("/"))))' "$1"
}

zip_file_content() {
    python3 -c 'import sys, zipfile; sys.stdout.write(zipfile.ZipFile(sys.argv[1]).read(sys.argv[2]).decode())' "$1" "$2"
}

# Tags HEAD of origin/main as the given tag, on the remote too
tag_main() {
    git -C "$REPO" tag "$1" origin/main
    git -C "$REPO" push -q origin "$1"
}

# --- The zip ------------------------------------------------------------------

@test "builds the zip from origin/main: one top-level folder with the mod and the release files" {
    release
    [ "$status" -eq 0 ]
    [ "$(zip_files "$ZIP")" = "$(printf '%s\n' \
        testmod/CHANGELOG.md testmod/CREDITS.txt testmod/LICENSE testmod/README.txt \
        testmod/content.xml testmod/libraries/god.xml testmod/md/sub/nested.xml)" ]
    [[ "$output" == *"dist/testmod-1.00.zip"* ]]
}

@test "the zip holds the latest origin/main, not the checked-out branch or local changes" {
    push_from_other_clone libraries/god.xml '<diff>from remote</diff>'
    git -C "$REPO" switch -q -c feature/wip
    echo 'uncommitted' > "$REPO/md/sub/nested.xml"

    release
    [ "$status" -eq 0 ]
    [ "$(zip_file_content "$ZIP" testmod/libraries/god.xml)" = '<diff>from remote</diff>' ]
    [ "$(zip_file_content "$ZIP" testmod/md/sub/nested.xml)" = '<mdscript/>' ]
}

@test "builds from a given tag, though main has moved on" {
    tag_main v1.00
    push_from_other_clone libraries/god.xml '<diff>after the tag</diff>'

    release --tag v1.00
    [ "$status" -eq 0 ]
    [ "$(zip_file_content "$ZIP" testmod/libraries/god.xml)" = '<diff/>' ]
}

@test "the version comes from content.xml: 101 is 1.01" {
    sed -i 's/version="100"/version="101"/' "$REPO/content.xml"
    printf '# Changelog\n\n## 1.01 - 2026-12-01\n' > "$REPO/CHANGELOG.md"
    commit_all "1.01"
    git -C "$REPO" push -q

    release
    [ "$status" -eq 0 ]
    [ -f "$REPO/dist/testmod-1.01.zip" ]
}

@test "writes the release checklist next to the zip" {
    release
    [ "$status" -eq 0 ]
    grep -q -- '- \[ \] \*\*The zip installs\*\* (manual)' "$REPO/dist/testmod-1.00-checklist.md"
}

@test "a second build replaces the zip" {
    release
    push_from_other_clone libraries/god.xml '<diff>second</diff>'

    release
    [ "$status" -eq 0 ]
    [ "$(zip_file_content "$ZIP" testmod/libraries/god.xml)" = '<diff>second</diff>' ]
}

# --- The tests ----------------------------------------------------------------

@test "runs the tests in a clean checkout of the commit it builds" {
    echo 'uncommitted' > "$REPO/libraries/god.xml"
    RELEASE_TEST="git rev-parse HEAD > '$SANDBOX/tested'; cat libraries/god.xml >> '$SANDBOX/tested'" release
    [ "$status" -eq 0 ]
    [ "$(cat "$SANDBOX/tested")" = "$(git -C "$REPO" rev-parse origin/main)"$'\n<diff/>' ]
}

@test "refuses to build when the tests fail" {
    RELEASE_TEST=false release
    [ "$status" -ne 0 ]
    [[ "$output" == *"tests failed"* ]]
    [ ! -e "$ZIP" ]
}

@test "removes its checkout afterwards, also when the tests fail" {
    release
    [ "$(git -C "$REPO" worktree list | wc -l)" -eq 1 ]

    RELEASE_TEST=false release
    [ "$(git -C "$REPO" worktree list | wc -l)" -eq 1 ]
}

# --- Tags and versions --------------------------------------------------------

@test "refuses when the version's tag is on a different commit" {
    tag_main v1.00
    push_from_other_clone libraries/god.xml '<diff>after the tag</diff>'

    release
    [ "$status" -ne 0 ]
    [[ "$output" == *"v1.00 is on"* ]]
    [ ! -e "$ZIP" ]
}

@test "builds origin/main when the version's tag is on that commit" {
    tag_main v1.00

    release
    [ "$status" -eq 0 ]
    [ -f "$ZIP" ]
}

@test "refuses a tag whose content.xml holds another version" {
    tag_main v1.01

    release --tag v1.01
    [ "$status" -ne 0 ]
    [[ "$output" == *"content.xml says 1.00"* ]]
}

@test "refuses an unknown tag" {
    release --tag v9.99
    [ "$status" -ne 0 ]
    [[ "$output" == *"no tag v9.99"* ]]
}

@test "refuses a tag whose CHANGELOG.md has no section for the version" {
    printf '# Changelog\n\n## Unreleased\n' > "$REPO/CHANGELOG.md"
    commit_all "no section"
    git -C "$REPO" push -q
    tag_main v1.00

    release --tag v1.00
    [ "$status" -ne 0 ]
    [[ "$output" == *"CHANGELOG.md has no '## 1.00' section"* ]]
    [ ! -e "$ZIP" ]
}

@test "a trial build of origin/main needs no changelog section yet" {
    printf '# Changelog\n\n## Unreleased\n' > "$REPO/CHANGELOG.md"
    commit_all "no section"
    git -C "$REPO" push -q

    release
    [ "$status" -eq 0 ]
    [ -f "$ZIP" ]
}

@test "refuses when a release file is missing" {
    git -C "$REPO" rm -q release/CREDITS.txt
    commit_all "no credits"
    git -C "$REPO" push -q

    release
    [ "$status" -ne 0 ]
    [[ "$output" == *"release/CREDITS.txt"* ]]
}

@test "an unknown option exits 2 with the usage" {
    release --nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage: tools/release.sh"* ]]
}
