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
    for target in setup deploy deploy-local deploy-dry-run test test-plan game-test game-test-report; do
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

@test "make game-test deploys the working tree, then runs the game tests" {
    echo '<diff>local</diff>' > "$REPO/libraries/god.xml"
    run make -C "$REPO" game-test GAME_TEST_RUNNER='echo game tests ran'
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>local</diff>'
    [[ "$output" == *"game tests ran"* ]]
}

@test "make game-test stops when the deploy fails" {
    run env X4_PATH="$SANDBOX/nope" make -C "$REPO" game-test GAME_TEST_RUNNER='echo game tests ran'
    [ "$status" -ne 0 ]
    [[ "$output" != *"game tests ran"* ]]
}

@test "make passes ARGS through to deploy.sh" {
    write_config
    run make -C "$REPO" deploy-local ARGS="--set IntactOnEject=0"
    [ "$status" -eq 0 ]
    [ "$(deployed_setting IntactOnEject)" = 0 ]
}

@test "make game-test passes ARGS through to the deploy" {
    write_config
    run make -C "$REPO" game-test ARGS="--set IntactOnClaim=0" GAME_TEST_RUNNER='echo game tests ran'
    [ "$status" -eq 0 ]
    [ "$(deployed_setting IntactOnClaim)" = 0 ]
    [[ "$output" == *"game tests ran"* ]]
}

@test "make game-test tells the runner which commit and branch it tests" {
    run make -C "$REPO" game-test GAME_TEST_RUNNER='echo runner'
    [ "$status" -eq 0 ]
    [[ "$output" == *"runner -Commit $(git -C "$REPO" rev-parse HEAD) -Branch main"* ]]
    [[ "$output" != *"-Dirty"* ]]
}

@test "make game-test flags uncommitted changes" {
    echo '<diff>local</diff>' > "$REPO/libraries/god.xml"
    run make -C "$REPO" game-test GAME_TEST_RUNNER='echo runner'
    [ "$status" -eq 0 ]
    [[ "$output" == *"-Branch main -Dirty"* ]]
}

@test "make test-plan regenerates docs/test-plan/" {
    mkdir -p "$REPO/tools" "$REPO/tests/game/features" "$REPO/tests/game/apirateslife_tests/md" "$REPO/tests/lua"
    cp "$REPO_ROOT/tools/test_plan_docs.py" "$REPO_ROOT/tools/check_test_plan.py" "$REPO/tools/"
    printf "<mdscript>\$name = 'alpha_works'</mdscript>\n" > "$REPO/tests/game/apirateslife_tests/md/apirateslife_tests.xml"
    printf 'Feature: Alpha\n\n  @alpha_works\n  Scenario: Alpha works\n    Then it works\n' > "$REPO/tests/game/features/alpha.feature"
    run make -C "$REPO" test-plan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updated 2 of 2 test-plan pages"* ]]
    grep -q '^# Alpha$' "$REPO/docs/test-plan/alpha.md"
}
