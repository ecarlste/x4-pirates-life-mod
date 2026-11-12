#!/usr/bin/env bats
# Tests for deploy.sh. Run with tests/run.sh (or `make test`).

load helpers

setup() { setup_sandbox; }
teardown() { teardown_sandbox; }

# --- What gets deployed -------------------------------------------------------

@test "default deploy fetches and ships the latest origin/main" {
    push_from_other_clone libraries/god.xml '<diff>from remote</diff>'

    deploy
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>from remote</diff>'
    [[ "$output" == *"Deploying origin/main @"* ]]
}

@test "default deploy ignores the checked-out branch and local changes" {
    git -C "$REPO" switch -q -c feature/wip
    echo '<diff>wip</diff>' > "$REPO/libraries/god.xml"
    commit_all "wip"
    echo 'uncommitted' > "$REPO/libraries/god.xml"

    deploy
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff/>'
}

@test "only paths in deploy.include are shipped" {
    deploy
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
    [ -f "$TARGET/md/sub/nested.xml" ]
    [ ! -e "$TARGET/docs" ]
    [ ! -e "$TARGET/deploy.sh" ]
    [ ! -e "$TARGET/Makefile" ]
}

@test "deploy.include comments, blank lines and missing entries are tolerated" {
    printf '# comment\n\ncontent.xml   # trailing comment\nlibraries\nnot-there\n' > "$REPO/deploy.include"
    commit_all "custom include"
    git -C "$REPO" push -q

    deploy
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
    [ -f "$TARGET/libraries/god.xml" ]
    [ ! -e "$TARGET/md" ]
}

# --- Mirroring ----------------------------------------------------------------

@test "files and folders that left the mod are removed" {
    mkdir -p "$TARGET/old/deeper"
    echo stale > "$TARGET/old/deeper/stale.xml"
    echo stale > "$TARGET/stale.xml"

    deploy
    [ "$status" -eq 0 ]
    [ ! -e "$TARGET/old" ]
    [ ! -e "$TARGET/stale.xml" ]
    [ -f "$TARGET/content.xml" ]
}

@test "changed files are updated and a repeat deploy is a no-op" {
    deploy
    echo 'tampered' > "$TARGET/libraries/god.xml"

    deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"libraries/god.xml"* ]]
    assert_file_content "$TARGET/libraries/god.xml" '<diff/>'

    deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"already up to date"* ]]
}

@test "nothing outside the mod folder is touched" {
    echo game > "$X4_PATH/X4.exe"
    mkdir -p "$X4_PATH/extensions/othermod"
    echo other > "$X4_PATH/extensions/othermod/content.xml"

    deploy
    [ "$status" -eq 0 ]
    assert_file_content "$X4_PATH/X4.exe" game
    assert_file_content "$X4_PATH/extensions/othermod/content.xml" other
}

@test "dry run lists changes but writes nothing" {
    deploy --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run"* ]]
    [[ "$output" == *"content.xml"* ]]
    [ ! -e "$TARGET" ]

    mkdir -p "$TARGET"
    echo stale > "$TARGET/stale.xml"
    deploy --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale.xml"* ]]
    [ -f "$TARGET/stale.xml" ]
}

@test "without rsync, the copy fallback mirrors the mod" {
    mkdir -p "$TARGET"
    echo stale > "$TARGET/stale.xml"

    run env PATH="$(path_with_only "${CORE_COMMANDS[@]}")" "$REPO/deploy.sh"
    [ "$status" -eq 0 ]
    [ -f "$TARGET/md/sub/nested.xml" ]
    [ ! -e "$TARGET/stale.xml" ]
}

@test "without rsync, dry run writes nothing" {
    run env PATH="$(path_with_only "${CORE_COMMANDS[@]}")" "$REPO/deploy.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"content.xml"* ]]
    [ ! -e "$TARGET" ]
}

# --- Sources: working tree and refs -------------------------------------------

@test "--working-tree ships uncommitted changes" {
    echo '<diff>uncommitted</diff>' > "$REPO/libraries/god.xml"

    deploy --working-tree
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>uncommitted</diff>'
    [[ "$output" == *"working tree (main)"* ]]
}

@test "--ref deploys the given branch" {
    git -C "$REPO" switch -q -c feature/x
    echo '<diff>branch</diff>' > "$REPO/libraries/god.xml"
    commit_all "branch change"
    git -C "$REPO" switch -q main

    deploy --ref feature/x
    [ "$status" -eq 0 ]
    assert_file_content "$TARGET/libraries/god.xml" '<diff>branch</diff>'
}

@test "--ref does not fetch" {
    git -C "$REPO" remote set-url origin "$SANDBOX/missing.git"

    deploy --ref main
    [ "$status" -eq 0 ]
    [[ "$output" != *"Couldn't fetch"* ]]
}

@test "unknown ref fails without touching the target" {
    deploy --ref does-not-exist
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown git ref: does-not-exist"* ]]
    [ ! -e "$TARGET" ]
}

@test "a ref without deploy.include fails" {
    git -C "$REPO" rm -q deploy.include
    commit_all "drop include"

    deploy --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"has no deploy.include"* ]]
}

@test "a ref without content.xml fails" {
    git -C "$REPO" rm -q content.xml
    commit_all "drop content"

    deploy --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"content.xml missing"* ]]
}

@test "an unreachable origin falls back to the last fetched origin/main" {
    git -C "$REPO" remote set-url origin "$SANDBOX/missing.git"

    deploy
    [ "$status" -eq 0 ]
    [[ "$output" == *"Couldn't fetch origin"* ]]
    [ -f "$TARGET/content.xml" ]
}

# --- Extension id safety ------------------------------------------------------

@test "unsafe extension ids are rejected before anything is deleted" {
    echo game > "$X4_PATH/X4.exe"
    for id in '..' '.' '../escape' 'a/b' 'a\b' '.hidden' ''; do
        write_content_xml "$id"
        deploy --working-tree
        [ "$status" -eq 1 ] || { echo "id '$id' was accepted"; return 1; }
        [[ "$output" == *"valid extension id"* ]]
    done
    assert_file_content "$X4_PATH/X4.exe" game
}

@test "the target folder is named after the id in content.xml" {
    write_content_xml other_mod-1.2
    deploy --working-tree
    [ "$status" -eq 0 ]
    [ -f "$X4_PATH/extensions/other_mod-1.2/content.xml" ]
}

# --- Configuration ------------------------------------------------------------

config_deploy() {
    unset X4_PATH
    printf '%s\n' "$@" > "$REPO/deploy.config"
    run "$REPO/deploy.sh" --working-tree
}

@test "missing deploy.config points at make setup" {
    unset X4_PATH
    deploy
    [ "$status" -eq 1 ]
    [[ "$output" == *"make setup"* ]]
}

@test "config path with spaces and parentheses works, quoted or not" {
    local x4="$SANDBOX/Program Files (x86)/X4 Foundations"
    mkdir -p "$x4"
    for line in "X4_PATH=\"$x4\"" "X4_PATH='$x4'" "X4_PATH=$x4" "  X4_PATH = \"$x4\"  "; do
        rm -rf "$x4/extensions"
        config_deploy "$line"
        [ "$status" -eq 0 ] || { echo "failed for: $line"; echo "$output"; return 1; }
        [ -f "$x4/extensions/testmod/content.xml" ]
    done
}

@test "config ignores comments and uses the last X4_PATH" {
    config_deploy "# X4_PATH=/nope" "X4_PATH=/also/nope" "X4_PATH=\"$SANDBOX/x4\""
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
}

@test "config is read, not executed" {
    # shellcheck disable=SC2016  # deliberately unexpanded: deploy.sh must not run it
    config_deploy "X4_PATH=\"$SANDBOX/x4\"" 'touch "$SANDBOX/pwned"' "\$(touch $SANDBOX/pwned2)"
    [ "$status" -eq 0 ]
    [ ! -e "$SANDBOX/pwned" ]
    [ ! -e "$SANDBOX/pwned2" ]
}

@test "empty X4_PATH in config fails" {
    config_deploy 'X4_PATH='
    [ "$status" -eq 1 ]
    [[ "$output" == *"X4_PATH not set"* ]]
}

@test "X4_PATH environment variable overrides deploy.config" {
    echo 'X4_PATH=/does/not/exist' > "$REPO/deploy.config"
    deploy --working-tree
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
}

@test "missing X4 folder fails" {
    run env X4_PATH="$SANDBOX/nope" "$REPO/deploy.sh" --working-tree
    [ "$status" -eq 1 ]
    [[ "$output" == *"X4 install folder not found"* ]]
}

@test "Windows paths are converted with wslpath" {
    local bin="$SANDBOX/stub"
    mkdir -p "$bin"
    cat > "$bin/wslpath" <<'STUB'
#!/usr/bin/env bash
[ "$1" = -u ] && [ "$2" = 'E:\Games\X4' ] && echo "$STUB_X4"
STUB
    chmod +x "$bin/wslpath"

    run env PATH="$bin:$PATH" STUB_X4="$SANDBOX/x4" X4_PATH='E:\Games\X4' "$REPO/deploy.sh" --working-tree
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
}

@test "Windows paths without wslpath fail clearly" {
    run env PATH="$(path_with_only "${CORE_COMMANDS[@]}")" X4_PATH='E:\Games\X4' "$REPO/deploy.sh" --working-tree
    [ "$status" -eq 1 ]
    [[ "$output" == *"wslpath"* ]]
}

# --- Arguments ----------------------------------------------------------------

@test "--help prints usage and succeeds" {
    deploy --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "bad arguments fail with usage" {
    deploy --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown option: --bogus"* ]]

    deploy --ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"--ref needs a value"* ]]

    deploy --ref main --working-tree
    [ "$status" -eq 1 ]
    [[ "$output" == *"can't be combined"* ]]
}

# --- Setting overrides (--set) ------------------------------------------------

@test "--set overrides a setting in the deployed copy only" {
    write_config
    deploy --working-tree --set CaptureFloorHull=20
    [ "$status" -eq 0 ]
    [[ "$output" == *"with settings: CaptureFloorHull=20"* ]]
    [ "$(deployed_setting CaptureFloorHull)" = 20 ]
    [ "$(deployed_setting IntactOnClaim)" = 1 ]
    grep -q 'APiratesLife_CaptureFloorHull" exact="35"' "$REPO/md/apirateslife_config.xml"
}

@test "--set accepts repeats and comma lists" {
    write_config
    deploy --working-tree --set CaptureFloorHull=20 --set IntactOnClaim=0
    [ "$status" -eq 0 ]
    [ "$(deployed_setting CaptureFloorHull)" = 20 ]
    [ "$(deployed_setting IntactOnClaim)" = 0 ]

    deploy --working-tree --set CaptureFloorHull=35,IntactOnClaim=0
    [ "$status" -eq 0 ]
    [ "$(deployed_setting CaptureFloorHull)" = 35 ]
    [ "$(deployed_setting IntactOnClaim)" = 0 ]
}

@test "--set works when deploying a git ref" {
    write_config
    commit_all "add config"
    deploy --ref HEAD --set IntactOnClaim=0
    [ "$status" -eq 0 ]
    [ "$(deployed_setting IntactOnClaim)" = 0 ]
}

@test "a later deploy without --set restores the committed values" {
    write_config
    deploy --working-tree --set CaptureFloorHull=20
    deploy --working-tree
    [ "$status" -eq 0 ]
    [ "$(deployed_setting CaptureFloorHull)" = 35 ]
}

@test "--set rejects unknown settings before deploying anything" {
    write_config
    deploy --working-tree --set Bogus=0
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown setting 'Bogus' (valid: CaptureFloorHull IntactOnClaim)"* ]]
    [ ! -e "$TARGET" ]
}

@test "--set rejects values that could break the XML" {
    write_config
    deploy --working-tree --set 'CaptureFloorHull=35"/><x'
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid value for CaptureFloorHull"* ]]
    [ ! -e "$TARGET" ]
}

@test "--set needs NAME=VALUE and a config file" {
    write_config
    deploy --working-tree --set CaptureFloorHull
    [ "$status" -eq 1 ]
    [[ "$output" == *"--set needs NAME=VALUE"* ]]

    deploy --working-tree --set
    [ "$status" -eq 1 ]
    [[ "$output" == *"--set needs NAME=VALUE"* ]]

    rm "$REPO/md/apirateslife_config.xml"
    deploy --working-tree --set CaptureFloorHull=20
    [ "$status" -eq 1 ]
    [[ "$output" == *"needs md/apirateslife_config.xml"* ]]
}

@test "--set with --dry-run reports the override and writes nothing" {
    write_config
    deploy --working-tree --dry-run --set CaptureFloorHull=20
    [ "$status" -eq 0 ]
    [[ "$output" == *"with settings: CaptureFloorHull=20"* ]]
    [ ! -e "$TARGET" ]
}

# --- Game lock ----------------------------------------------------------------

@test "refuses while another run holds the game lock, naming it" {
    write_game_lock

    X4_GAME_LOCK_WAIT=0 deploy --working-tree
    [ "$status" -ne 0 ]
    [[ "$output" == *"game-test (x4-swi-bounty-hunter, feature/other)"* ]]
    [ ! -e "$TARGET" ]
}

@test "waits for the holder to finish, then deploys and frees the lock" {
    write_game_lock
    X4_GAME_LOCK_POLL=0.2 "$REPO/deploy.sh" --working-tree > "$SANDBOX/out" 2>&1 &
    pid=$!
    # The holder finishes once the deploy is waiting for it
    for _ in $(seq 300); do grep -q "Waiting for the game lock" "$SANDBOX/out" && break; sleep 0.1; done
    rm -f "$X4_PATH/game.lock"
    status=0
    wait "$pid" || status=$?

    [ "$status" -eq 0 ]
    grep -q "held by game-test (x4-swi-bounty-hunter, feature/other)" "$SANDBOX/out"
    [ -f "$TARGET/content.xml" ]
    [ ! -e "$X4_PATH/game.lock" ]
}

@test "takes over a lock that stopped changing, as from a crashed run" {
    write_game_lock

    X4_GAME_LOCK_STALE=1 X4_GAME_LOCK_POLL=0.2 deploy --working-tree
    [ "$status" -eq 0 ]
    [[ "$output" == *"looks crashed"* ]]
    [ -f "$TARGET/content.xml" ]
    [ ! -e "$X4_PATH/game.lock" ]
}

@test "a dry run doesn't need the game lock" {
    write_game_lock

    X4_GAME_LOCK_WAIT=0 deploy --working-tree --dry-run
    [ "$status" -eq 0 ]
    [ -e "$X4_PATH/game.lock" ]
}

@test "deploys under a lock its caller holds and leaves it to the caller" {
    write_game_lock

    X4_GAME_LOCK_WAIT=0 X4_GAME_LOCK_TOKEN=other deploy --working-tree
    [ "$status" -eq 0 ]
    [ -f "$TARGET/content.xml" ]
    [[ "$(cat "$X4_PATH/game.lock")" == token=other* ]]
}

@test "frees the game lock when the deploy fails after taking it" {
    # A file where the extension folder should be: the mirror fails, after the lock is taken
    echo 'not a folder' > "$TARGET"

    deploy --working-tree
    [ "$status" -ne 0 ]
    [[ "$output" == *"Deploying working tree"* ]]
    [ ! -e "$X4_PATH/game.lock" ]
}
