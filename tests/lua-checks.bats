#!/usr/bin/env bats
# Tests for tests/lua/run.sh: luacheck must catch an unknown global, and a failing Lua unit test
# must fail the run. Fixtures are written into a temporary folder. Skipped where the tools can't
# run (luacheck needs Linux x86_64; the unit tests need LuaJIT).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    RUN="$REPO_ROOT/tests/lua/run.sh"
    FIXTURES="$BATS_TEST_TMPDIR/lua"
    mkdir -p "$FIXTURES"
    printf 'local lu = require("luaunit")\nTestOk = {}\nfunction TestOk:test_passes() lu.assertEquals(1, 1) end\nos.exit(lu.LuaUnit.run())\n' > "$FIXTURES/test_ok.lua"
}

needs_luacheck() { [ "$(uname -s)-$(uname -m)" = Linux-x86_64 ] || skip "luacheck has no build here"; }
needs_luajit() { command -v luajit >/dev/null || skip "LuaJIT is not installed"; }

@test "the real Lua passes lint and its unit tests" {
    needs_luacheck
    needs_luajit
    run "$RUN"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 warnings / 0 errors"* ]]
}

@test "luacheck fails on a global X4 doesn't provide" {
    needs_luacheck
    printf 'local x = 1\nNotAnX4Function(x)\n' > "$FIXTURES/bad.lua"
    LUA_LINT_PATHS="$FIXTURES/bad.lua" LUA_TESTS_DIR="$FIXTURES" run "$RUN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"accessing undefined variable 'NotAnX4Function'"* ]]
}

@test "a failing Lua unit test fails the run" {
    needs_luajit
    printf 'local lu = require("luaunit")\nTestBad = {}\nfunction TestBad:test_fails() lu.assertEquals(1, 2) end\nos.exit(lu.LuaUnit.run())\n' > "$FIXTURES/test_bad.lua"
    LUA_LINT_PATHS="$FIXTURES/test_ok.lua" LUA_TESTS_DIR="$FIXTURES" run "$RUN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"TestBad.test_fails ... FAIL"* ]]
}

@test "fails when there are no unit tests to run" {
    needs_luajit
    rm "$FIXTURES/test_ok.lua"
    printf 'local ok = true\nreturn ok\n' > "$FIXTURES/lib.lua"
    LUA_LINT_PATHS="$FIXTURES/lib.lua" LUA_TESTS_DIR="$FIXTURES" run "$RUN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No unit tests in"* ]]
}
