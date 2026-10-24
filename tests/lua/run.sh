#!/usr/bin/env bash

# Lua checks for the mod's UI Lua and the test extension's Lua:
#   - luacheck (lint and syntax), with .luacheckrc; the standalone Linux build is fetched into .tools/
#   - the unit tests (tests/lua/test_*.lua) with LuaUnit, under LuaJIT, the runtime X4 uses
# Tools are pinned and checked against their SHA-256. Each check skips with a note when it can't run
# here (luacheck has no macOS build; LuaJIT isn't installed). CI runs both on Linux.
#
# Usage: tests/lua/run.sh
# Overrides, for the tests of this script: LUA_LINT_PATHS (space-separated), LUA_TESTS_DIR

set -euo pipefail

LUACHECK_VERSION=1.2.0
LUACHECK_SHA256=d68da17fca0697d9e2fb04201f3884abd259fa558b3a449bccaed47f1390defc
LUAUNIT_VERSION=3.5
LUAUNIT_SHA256=150ed14606ea66c6a02b3142dde02bdf6d48764fcd2af6bf85bfecd7d98a7d0b

cd "$(dirname "$0")/../.."

LINT_PATHS=${LUA_LINT_PATHS:-ui tests/game/apirateslife_tests/ui tests/lua}
TESTS_DIR=${LUA_TESTS_DIR:-tests/lua}

sha256() {
    if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# fetch <url> <file> <sha256>: downloads into .tools/ once, keeping it only if the hash matches
fetch() {
    [ -f "$2" ] && return 0
    mkdir -p "$(dirname "$2")"
    echo "Fetching $(basename "$2") into .tools/"
    curl -fsSL --retry 3 -o "$2.part" "$1"
    local got
    got=$(sha256 "$2.part")
    if [ "$got" != "$3" ]; then
        rm -f "$2.part"
        echo "SHA-256 of $1 is $got, expected $3" >&2
        return 1
    fi
    mv "$2.part" "$2"
}

FAILED=0

echo "== luacheck"
if [ "$(uname -s)-$(uname -m)" = Linux-x86_64 ]; then
    LUACHECK=.tools/luacheck-$LUACHECK_VERSION/luacheck
    fetch "https://github.com/lunarmodules/luacheck/releases/download/v$LUACHECK_VERSION/luacheck" "$LUACHECK" "$LUACHECK_SHA256"
    chmod +x "$LUACHECK"
    # shellcheck disable=SC2086  # LINT_PATHS is a list
    "$LUACHECK" --no-color $LINT_PATHS || FAILED=1
else
    echo "luacheck has no build for $(uname -s) $(uname -m); skipping (CI runs it)"
fi

echo "== Lua unit tests"
if command -v luajit >/dev/null; then
    LUAUNIT_DIR=.tools/luaunit-$LUAUNIT_VERSION
    fetch "https://raw.githubusercontent.com/bluebird75/luaunit/LUAUNIT_V${LUAUNIT_VERSION/./_}/luaunit.lua" "$LUAUNIT_DIR/luaunit.lua" "$LUAUNIT_SHA256"
    shopt -s nullglob
    tests=("$TESTS_DIR"/test_*.lua)
    if [ ${#tests[@]} -eq 0 ]; then
        echo "No unit tests in $TESTS_DIR" >&2
        FAILED=1
    fi
    for test in "${tests[@]}"; do
        echo "-- $test"
        LUA_PATH="$TESTS_DIR/?.lua;tests/lua/?.lua;$LUAUNIT_DIR/?.lua;;" luajit "$test" --verbose || FAILED=1
    done
else
    echo "LuaJIT not installed; skipping (CI runs it). To run locally: sudo apt install luajit"
fi

exit "$FAILED"
