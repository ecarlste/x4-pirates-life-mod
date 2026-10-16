#!/usr/bin/env bats
# Tests for the Makefile targets. Skipped when make isn't installed.

# shellcheck disable=SC2153  # TARGET comes from helpers.bash
load helpers

setup() {
    command -v make >/dev/null || skip "make is not installed"
    setup_sandbox
}
teardown() { if [ -n "${SANDBOX:-}" ]; then teardown_sandbox; fi; }

@test "make help lists every target" {
    run make -C "$REPO" help
    [ "$status" -eq 0 ]
    for target in setup deploy deploy-local deploy-dry-run test; do
        [[ "$output" == *"make $target "* ]] || { echo "missing: $target"; return 1; }
    done
}

@test "make setup creates deploy.config from the example" {
    run make -C "$REPO" setup
    [ "$status" -eq 0 ]
    cmp "$REPO/deploy.config" "$REPO/deploy.config.example"
}

@test "make setup never overwrites an existing deploy.config" {
    echo 'X4_PATH=/mine' > "$REPO/deploy.config"
    run make -C "$REPO" setup
    [ "$status" -eq 0 ]
    [[ "$output" == *"already exists"* ]]
    assert_file_content "$REPO/deploy.config" 'X4_PATH=/mine'
}

@test "make deploy ships origin/main" {
    push_from_other_clone libraries/god.xml '<diff>remote</diff>'
    run make -C "$REPO" deploy
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>remote</diff>'
}

@test "make deploy-local ships the working tree" {
    echo '<diff>local</diff>' > "$REPO/libraries/god.xml"
    run make -C "$REPO" deploy-local
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>local</diff>'
}

@test "make deploy-dry-run writes nothing" {
    run make -C "$REPO" deploy-dry-run
    [ "$status" -eq 0 ]
    [ ! -e "$TARGET" ]
}

@test "make deploy fails when deploy.sh fails" {
    run env X4_PATH="$SANDBOX/nope" make -C "$REPO" deploy
    [ "$status" -ne 0 ]
}
