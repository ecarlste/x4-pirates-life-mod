#!/usr/bin/env bats
# Tests for tests/run.sh's last line, which names the run's result. run.sh is copied into a
# temporary folder with stub suites (bats, the Lua checks) that pass or fail on demand.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    WORK="$BATS_TEST_TMPDIR/repo"
    BATS="$WORK/.tools/bats-core-$(sed -n 's/^BATS_VERSION=//p' "$REPO_ROOT/tests/run.sh")/bin/bats"
    mkdir -p "$WORK/tests/lua" "$WORK/tools" "$(dirname "$BATS")"
    cp "$REPO_ROOT/tests/run.sh" "$WORK/tests/"
    touch "$WORK/tests/stub.bats"
    stub "$BATS" 0
    stub "$WORK/tests/lua/run.sh" 0
    # The test-plan check passes, so it prints no warning
    printf 'import sys\nsys.exit(0)\n' > "$WORK/tools/test_plan_docs.py"
}

# stub <path> <exit code>: a script that prints its name and exits with that code
stub() {
    printf '#!/bin/sh\necho "stub %s"\nexit %s\n' "$(basename "$1")" "$2" > "$1"
    chmod +x "$1"
}

run_picked() { run "$WORK/tests/run.sh" --bash-only --suites "tests/stub.bats lua"; }

@test "a passing run ends with All suites passed" {
    run_picked
    echo "$output"
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "All suites passed" ]
}

@test "a failing run ends with FAILED: and the failing suite" {
    stub "$WORK/tests/lua/run.sh" 1
    run_picked
    echo "$output"
    [ "$status" -eq 1 ]
    [ "${lines[-1]}" = "FAILED: Lua" ]
}

@test "the FAILED line names every failing suite, in the order they ran" {
    stub "$BATS" 1
    stub "$WORK/tests/lua/run.sh" 1
    run_picked
    echo "$output"
    [ "$status" -eq 1 ]
    [ "${lines[-1]}" = "FAILED: bats, Lua" ]
}

@test "the test-plan warning comes before the result line" {
    printf 'import sys\nsys.exit(1)\n' > "$WORK/tools/test_plan_docs.py"
    run_picked
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "${lines[-2]}" == "WARNING: the test-plan docs"* ]]
    [ "${lines[-1]}" = "All suites passed" ]
}
