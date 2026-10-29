#!/usr/bin/env bats
# Tests for tools/post-game-test-report.sh, with a fake gh that logs its calls instead of posting.

# shellcheck disable=SC2153  # REPO, SANDBOX etc. come from helpers.bash

load helpers

setup() {
    setup_sandbox
    mkdir -p "$REPO/tools" "$REPO/tests/game"
    cp "$REPO_ROOT/tools/post-game-test-report.sh" "$REPO/tools/"
    commit_all "add poster"
    HEAD_SHA=$(git -C "$REPO" rev-parse HEAD)

    # Fake gh: "pr view" answers with $FAKE_PR ("<number> <head sha> <state>"), or fails when
    # it's empty (no PR); every other call is logged to gh.log
    mkdir -p "$SANDBOX/fakebin"
    cat > "$SANDBOX/fakebin/gh" <<'SH'
#!/bin/sh
if [ "$1 $2" = "pr view" ]; then
    [ -n "$FAKE_PR" ] || exit 1
    echo "$FAKE_PR"
    exit 0
fi
echo "$*" >> "$GH_LOG"
SH
    chmod +x "$SANDBOX/fakebin/gh"
    export PATH="$SANDBOX/fakebin:$PATH" GH_LOG="$SANDBOX/gh.log"
    export FAKE_PR="7 $HEAD_SHA OPEN"
}
teardown() { teardown_sandbox; }

# write_report <commit> <dirty> <result> <passed> <total>
write_report() {
    printf '<!-- apirateslife-game-tests commit=%s dirty=%s result=%s passed=%s total=%s -->\n### Game tests\n' \
        "$1" "$2" "$3" "$4" "$5" > "$REPO/tests/game/report.md"
}

post() { run "$REPO/tools/post-game-test-report.sh" "$@"; }

@test "posts the report as a comment and a passing game-tests status" {
    write_report "$HEAD_SHA" false pass 5 5
    post
    [ "$status" -eq 0 ]
    [[ "$output" == *"Posted to PR #7: game-tests success (5 of 5 passed (local run))"* ]]
    grep -q "^pr comment 7 --body-file tests/game/report.md$" "$GH_LOG"
    grep -q "statuses/$HEAD_SHA -f state=success -f context=game-tests" "$GH_LOG"
}

@test "posts a failing run as a failure status" {
    write_report "$HEAD_SHA" false fail 4 5
    post
    [ "$status" -eq 0 ]
    grep -q "state=failure -f context=game-tests -f description=4 of 5 passed (local run)" "$GH_LOG"
}

@test "a run of only the tests the change needs says how many weren't needed" {
    write_report "$HEAD_SHA" false pass 3 "3 of=18"
    post
    [ "$status" -eq 0 ]
    grep -q "state=success -f context=game-tests -f description=3 of 3 passed, 15 not needed (local run)" "$GH_LOG"
}

@test "a change that needed no game test posts as passing" {
    write_report "$HEAD_SHA" false pass 0 "0 of=18"
    post
    [ "$status" -eq 0 ]
    grep -q "^pr comment 7 " "$GH_LOG"
    grep -q "state=success -f context=game-tests -f description=none needed for this change (local check)" "$GH_LOG"
}

@test "refuses a run with uncommitted changes" {
    write_report "$HEAD_SHA" true pass 5 5
    post
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [ ! -e "$GH_LOG" ]
}

@test "refuses a report for another commit than HEAD" {
    write_report 0123456789abcdef0123456789abcdef01234567 false pass 5 5
    post
    [ "$status" -ne 0 ]
    [[ "$output" == *"the report is for 0123456, but HEAD is ${HEAD_SHA:0:7}"* ]]
    [ ! -e "$GH_LOG" ]
}

@test "refuses when the PR's latest commit isn't the tested one" {
    write_report "$HEAD_SHA" false pass 5 5
    export FAKE_PR="7 0123456789abcdef0123456789abcdef01234567 OPEN"
    post
    [ "$status" -ne 0 ]
    [[ "$output" == *"PR #7's latest commit is 0123456, not the tested ${HEAD_SHA:0:7}"* ]]
    [ ! -e "$GH_LOG" ]
}

@test "refuses when the branch has no PR, or it isn't open" {
    write_report "$HEAD_SHA" false pass 5 5
    FAKE_PR='' post
    [ "$status" -ne 0 ]
    [[ "$output" == *"no PR found"* ]]
    FAKE_PR="7 $HEAD_SHA MERGED" post
    [ "$status" -ne 0 ]
    [[ "$output" == *"PR #7 is MERGED"* ]]
    [ ! -e "$GH_LOG" ]
}

@test "refuses without a report, or with a file that isn't one" {
    post
    [ "$status" -ne 0 ]
    [[ "$output" == *"run make game-test first"* ]]
    echo '# notes' > "$REPO/tests/game/report.md"
    post
    [ "$status" -ne 0 ]
    [[ "$output" == *"isn't a game-test report"* ]]
}

@test "dry run checks and prints, but posts nothing" {
    write_report "$HEAD_SHA" false pass 5 5
    post --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would comment on PR #7 and set game-tests=success"* ]]
    [[ "$output" == *"### Game tests"* ]]
    [ ! -e "$GH_LOG" ]
}

@test "reads another report with --report" {
    write_report "$HEAD_SHA" false pass 5 5
    mv "$REPO/tests/game/report.md" "$SANDBOX/other.md"
    post --report "$SANDBOX/other.md"
    [ "$status" -eq 0 ]
    grep -q "body-file $SANDBOX/other.md" "$GH_LOG"
}
