#!/usr/bin/env bash

# Runs every test suite available on this machine:
#   - bats suites for deploy.sh and the Makefile (bats-core is fetched into .tools/ on first run)
#   - shellcheck, when installed
#   - the Lua checks (tests/lua/run.sh: luacheck and the LuaUnit tests, under LuaJIT)
#   - the Python unit tests for tools/ (tests/python/, with the standard library's unittest)
#   - the Pester suites under PowerShell 7: pwsh if installed, else Microsoft's Linux build
#     fetched into .tools/ (pinned by SHA-256), one process per test file, in parallel. CI also
#     runs them under Windows PowerShell 5.1; --windows-powershell does that here (under WSL).
#
# Usage: tests/run.sh [--bash-only | --lua-only | --windows-powershell] [bats args...]
#   --bash-only  skip PowerShell; --lua-only  only the Lua checks
#   --windows-powershell  run the Pester suites in Windows PowerShell 5.1 (WSL; slower, serial)
# bats runs its test files in parallel when GNU parallel is installed (sudo apt install parallel).

set -eo pipefail

BATS_VERSION=v1.11.1
PWSH_VERSION=7.6.9
PWSH_SHA256=1da6d6d6035d651f20e70ddee7c4c15ac6ab8b9fb40ee92240d91263f28a884b

cd "$(dirname "$0")/.."

BASH_ONLY=0
WINDOWS_POWERSHELL=0
if [ "${1:-}" = --bash-only ]; then BASH_ONLY=1; shift; fi
if [ "${1:-}" = --windows-powershell ]; then WINDOWS_POWERSHELL=1; shift; fi
if [ "${1:-}" = --lua-only ]; then exec tests/lua/run.sh; fi

BATS=.tools/bats-core-$BATS_VERSION/bin/bats
if [ ! -x "$BATS" ]; then
    echo "Fetching bats-core $BATS_VERSION into .tools/"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$BATS_VERSION" \
        https://github.com/bats-core/bats-core.git ".tools/bats-core-$BATS_VERSION"
fi

FAILED=0

# Prints the PowerShell 7 to use: pwsh from PATH, or Microsoft's Linux x64 build fetched into .tools/
find_pwsh() {
    if command -v pwsh >/dev/null; then
        command -v pwsh
        return
    fi
    [ "$(uname -s)-$(uname -m)" = Linux-x86_64 ] || return 1
    local dir=.tools/powershell-$PWSH_VERSION
    if [ ! -x "$dir/pwsh" ]; then
        echo "Fetching PowerShell $PWSH_VERSION into .tools/" >&2
        local tgz
        tgz=$(mktemp)
        curl -fsSL --retry 3 -o "$tgz" \
            "https://github.com/PowerShell/PowerShell/releases/download/v$PWSH_VERSION/powershell-$PWSH_VERSION-linux-x64.tar.gz" || return 1
        if [ "$(sha256sum "$tgz" | cut -d' ' -f1)" != "$PWSH_SHA256" ]; then
            echo "PowerShell download doesn't match its SHA-256" >&2
            rm -f "$tgz"
            return 1
        fi
        rm -rf "$dir" && mkdir -p "$dir" && tar -xzf "$tgz" -C "$dir" && chmod +x "$dir/pwsh"
        rm -f "$tgz"
    fi
    echo "$dir/pwsh"
}

# Runs each Pester file in its own PowerShell process, all at once, then prints each file's output
run_pester_parallel() {
    local pwsh=$1 logs file name failed=0
    "$pwsh" -NoProfile -File tests/run.ps1 -SetupOnly || return 1
    logs=$(mktemp -d)
    for file in tests/*.Tests.ps1; do
        name=$(basename "$file")
        ( "$pwsh" -NoProfile -File tests/run.ps1 -Path "$file" > "$logs/$name.log" 2>&1; echo $? > "$logs/$name.rc" ) &
    done
    wait
    for file in tests/*.Tests.ps1; do
        name=$(basename "$file")
        cat "$logs/$name.log"
        [ "$(cat "$logs/$name.rc")" = 0 ] || { echo "FAILED: $name"; failed=1; }
    done
    rm -rf "$logs"
    return "$failed"
}

# Pester takes longest, so it starts first, in the background, while the other suites run
start_pester() {
    if [ "$WINDOWS_POWERSHELL" = 1 ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)"
    elif PWSH=$(find_pwsh); then
        # Without ICU (sudo apt install libicu78), .NET needs invariant globalization; the tests don't notice
        if ! ldconfig -p 2>/dev/null | grep -q libicuuc; then export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1; fi
        run_pester_parallel "$PWSH"
    elif command -v powershell.exe >/dev/null && command -v wslpath >/dev/null; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)"
    else
        echo "No PowerShell found; skipping (CI runs it)"
    fi
}
if [ "$BASH_ONLY" = 0 ]; then
    PESTER_LOG=$(mktemp)
    start_pester > "$PESTER_LOG" 2>&1 &
    PESTER_PID=$!
fi


# Run the given test files, or every suite when none are named
SUITES=(tests/*.bats)
for arg in "$@"; do case "$arg" in *.bats) SUITES=(); break ;; esac; done

echo "== bats"
# bats' own --jobs needs GNU parallel. Files run side by side; tests within a file stay in order
JOBS=()
if command -v parallel >/dev/null; then
    JOBS=(--jobs "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" --no-parallelize-within-files)
fi
"$BATS" "${JOBS[@]}" "$@" "${SUITES[@]}" || FAILED=1

echo "== shellcheck"
if command -v shellcheck >/dev/null; then
    shellcheck deploy.sh tests/run.sh tests/lua/run.sh tools/post-game-test-report.sh && shellcheck -s bash tests/*.bash tests/*.bats || FAILED=1
else
    echo "shellcheck not installed; skipping (CI runs it)"
fi

tests/lua/run.sh || FAILED=1

echo "== Python unit tests"
if command -v python3 >/dev/null; then
    PYTHONPATH=tools python3 -m unittest discover -s tests/python || FAILED=1
else
    echo "python3 not installed; skipping (CI runs them)"
fi

if [ "$BASH_ONLY" = 0 ]; then
    # Started at the top, in the background; its output comes last
    echo "== Pester"
    wait "$PESTER_PID" || FAILED=1
    cat "$PESTER_LOG"
    rm -f "$PESTER_LOG"
fi

# Last, so it's the line people see: the generated test plan doesn't fail a local run, CI checks it
if command -v python3 >/dev/null && ! python3 tools/test_plan_docs.py --check >/dev/null 2>&1; then
    echo
    echo "WARNING: the test-plan docs (docs/test-plan/) are out of date. Run make test-plan and commit the result; CI fails on this."
fi

exit "$FAILED"
