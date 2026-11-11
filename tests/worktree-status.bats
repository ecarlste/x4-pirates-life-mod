#!/usr/bin/env bats
# Tests for tools/worktree-status.sh: flags worktrees with uncommitted changes or commits that
# reached neither a remote nor main, and treats squash-merged work as landed. Each test builds a
# bare origin and a clone in its own temporary folder.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    STATUS="$REPO_ROOT/tools/worktree-status.sh"
    export WORKTREE_STATUS_NO_GH=1
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
    export GIT_CONFIG_GLOBAL=/dev/null
    git init -q --bare -b main "$BATS_TEST_TMPDIR/origin.git"
    git clone -q "$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/repo" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/repo" || return
    git switch -q -c main 2>/dev/null || true
    echo one > file.txt
    git add file.txt && git commit -q -m one && git push -q -u origin main
    WT="$BATS_TEST_TMPDIR/wt"
}

# worktree <branch>: adds a worktree on a new branch from main
worktree() { git worktree add -q -b "$1" "$WT" main; }

@test "a clean worktree on main is fine" {
    run "$STATUS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| main | on origin/main"* ]]
}

@test "uncommitted changes in a worktree are at risk" {
    worktree feature/a
    echo change >> "$WT/file.txt"
    run "$STATUS"
    [ "$status" -eq 1 ]
    [[ "$output" == *"| feature/a | UNCOMMITTED: 1 changed files"* ]]
}

@test "a commit on no remote is at risk" {
    worktree feature/a
    echo change >> "$WT/file.txt"
    git -C "$WT" commit -q -am change
    run "$STATUS"
    [ "$status" -eq 1 ]
    [[ "$output" == *"| feature/a | UNPUSHED: 1 commits"* ]]
}

@test "a squash-merged branch counts as landed and can be removed" {
    worktree feature/a
    echo change >> "$WT/file.txt"
    git -C "$WT" commit -q -am change
    echo change >> file.txt
    git commit -q -am "change (#1)" && git push -q origin main
    run "$STATUS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| feature/a | on origin/main, can be removed"* ]]
}

@test "a pushed branch not on main is fine" {
    worktree research/a
    echo note > "$WT/note.md"
    git -C "$WT" add note.md && git -C "$WT" commit -q -m note && git -C "$WT" push -q -u origin research/a
    run "$STATUS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| research/a | pushed"* ]]
}

@test "--hook prints nothing when no work is at risk" {
    run "$STATUS" --hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "--hook prints a JSON message naming the worktree at risk, and still exits 0" {
    worktree feature/a
    echo change >> "$WT/file.txt"
    run "$STATUS" --hook
    [ "$status" -eq 0 ]
    python3 -c 'import json, sys; m = json.loads(sys.argv[1]); assert "feature/a" in m["systemMessage"]; assert m["hookSpecificOutput"]["hookEventName"] == "SessionStart"' "$output"
}
