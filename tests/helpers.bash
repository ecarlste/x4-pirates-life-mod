# shellcheck disable=SC2034  # TARGET, CORE_COMMANDS etc. are used by the .bats files that load this
# Shared setup for the bats suites. Each test gets a throwaway sandbox with:
#   $ORIGIN  a bare repo standing in for GitHub
#   $REPO    a clone holding the real deploy scripts plus a small test mod (id "testmod")
#   $X4_PATH a fake X4 install; $TARGET is where the mod should land

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup_sandbox() {
    SANDBOX="$(mktemp -d)"

    # Isolate git from the developer's own config (signing, hooks, default branch)
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

    export X4_PATH="$SANDBOX/x4"
    mkdir -p "$X4_PATH/extensions"
    TARGET="$X4_PATH/extensions/testmod"

    ORIGIN="$SANDBOX/origin.git"
    git init -q --bare -b main "$ORIGIN"

    REPO="$SANDBOX/repo"
    git init -q -b main "$REPO"
    cp "$REPO_ROOT/deploy.sh" "$REPO_ROOT/deploy.include" "$REPO_ROOT/deploy.config.example" "$REPO_ROOT/Makefile" "$REPO/"
    write_content_xml testmod
    mkdir -p "$REPO/libraries" "$REPO/md/sub" "$REPO/docs"
    echo '<diff/>' > "$REPO/libraries/god.xml"
    echo '<mdscript/>' > "$REPO/md/sub/nested.xml"
    echo 'not part of the mod' > "$REPO/docs/notes.md"
    commit_all "initial"
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q -u origin main
}

teardown_sandbox() {
    rm -rf "$SANDBOX"
}

write_content_xml() {
    printf '<?xml version="1.0" encoding="utf-8"?>\n<content id="%s" name="Test" version="100" save="false"/>\n' "$1" > "$REPO/content.xml"
}

commit_all() {
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "$1"
}

# Simulate another developer merging to main on the remote
push_from_other_clone() {
    local other="$SANDBOX/other"
    [ -d "$other" ] || git clone -q "$ORIGIN" "$other"
    git -C "$other" pull -q
    mkdir -p "$(dirname "$other/$1")"
    echo "$2" > "$other/$1"
    git -C "$other" add -A
    git -C "$other" commit -q -m "change $1"
    git -C "$other" push -q origin main
}

deploy() {
    run "$REPO/deploy.sh" "$@"
}

# Builds a bin dir with only the listed commands, so tests can hide one (like rsync)
path_with_only() {
    local bin="$SANDBOX/bin" cmd src
    mkdir -p "$bin"
    for cmd in "$@"; do
        src="$(command -v "$cmd")" && ln -sf "$src" "$bin/$cmd"
    done
    echo "$bin"
}

# Commands deploy.sh needs, minus rsync
CORE_COMMANDS=(bash sh env git tar sed mktemp rm mkdir cp find grep head tail dirname cat)

assert_file_content() {
    [ -f "$1" ] || { echo "missing file: $1"; return 1; }
    [ "$(cat "$1")" = "$2" ] || { echo "unexpected content in $1: $(cat "$1")"; return 1; }
}
