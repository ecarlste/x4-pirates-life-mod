#!/usr/bin/env bash

# Runs the test suites your changes need, of those available on this machine. tools/select_tests.py
# picks them from the files changed since your branch left origin/main (uncommitted ones
# included), by the path filters in .github/test-filters.json, which CI uses too:
#   - bats suites for deploy.sh and the Makefile (bats-core is fetched into .tools/ on first run)
#   - shellcheck, when installed
#   - the Lua checks (tests/lua/run.sh: luacheck and the LuaUnit tests, under LuaJIT)
#   - the Python unit tests for tools/ (tests/python/, with the standard library's unittest)
#   - the Pester suites under PowerShell 7: pwsh if installed, else Microsoft's Linux build
#     fetched into .tools/ (pinned by SHA-256), one process per test file, in parallel. CI also
#     runs them under Windows PowerShell 5.1; --windows-powershell does that here (under WSL).
#
# Usage: tests/run.sh [--all | --suites "<suite>..."] [--bash-only | --lua-only | --windows-powershell] [bats args...]
#   --all        every suite, whatever changed; --suites  just these (the filter names, as CI passes)
#   --bash-only  skip PowerShell; --lua-only  only the Lua checks
#   --windows-powershell  run the Pester suites in Windows PowerShell 5.1 (WSL; slower, serial)
#   .bats files  run just those bats files (and the other suites as picked)
# bats runs its test files in parallel when GNU parallel is installed (sudo apt install parallel).

set -eo pipefail

BATS_VERSION=v1.11.1
PWSH_VERSION=7.6.9
PWSH_SHA256=1da6d6d6035d651f20e70ddee7c4c15ac6ab8b9fb40ee92240d91263f28a884b

cd "$(dirname "$0")/.."

BASH_ONLY=0
WINDOWS_POWERSHELL=0
PICKED=
ALL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --all) ALL=1 ;;
        --suites) PICKED=" $2 "; shift ;;
        --bash-only) BASH_ONLY=1 ;;
        --windows-powershell) WINDOWS_POWERSHELL=1 ;;
        --lua-only) exec tests/lua/run.sh ;;
        *) break ;;
    esac
    shift
done
if [ -z "$PICKED" ] && [ "$ALL" = 0 ]; then
    if command -v python3 >/dev/null; then
        PICKED=" $(python3 tools/select_tests.py | tr '\n' ' ') "
        [ "$PICKED" != "  " ] || echo "Nothing to test (make test ALL=1 runs everything)"
    else
        ALL=1
    fi
fi
case "$PICKED" in *" everything "*) ALL=1 ;; esac

# wanted <suite>: whether to run it (a filter name in .github/test-filters.json)
wanted() { [ "$ALL" = 1 ] || case "$PICKED" in *" $1 "*) true ;; *) false ;; esac; }
PESTER_FILES=()
for file in tests/*.Tests.ps1; do wanted "$file" && PESTER_FILES+=("$file"); done
PYTHON_TESTS=()
for file in tests/python/test_*.py; do wanted "$file" && PYTHON_TESTS+=("$(basename "$file" .py)"); done

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
    for file in "${PESTER_FILES[@]}"; do
        name=$(basename "$file")
        ( "$pwsh" -NoProfile -File tests/run.ps1 -Path "$file" > "$logs/$name.log" 2>&1; echo $? > "$logs/$name.rc" ) &
    done
    wait
    for file in "${PESTER_FILES[@]}"; do
        name=$(basename "$file")
        cat "$logs/$name.log"
        [ "$(cat "$logs/$name.rc")" = 0 ] || { echo "FAILED: $name"; failed=1; }
    done
    rm -rf "$logs"
    return "$failed"
}

# Pester takes longest, so it starts first, in the background, while the other suites run
start_pester() {
    local only=()
    [ "$ALL" = 1 ] || only=(-Path "$(IFS=,; echo "${PESTER_FILES[*]}")")
    if [ ${#PESTER_FILES[@]} = 0 ]; then
        echo "No Pester suites needed"
    elif [ "$WINDOWS_POWERSHELL" = 1 ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)" "${only[@]}"
    elif PWSH=$(find_pwsh); then
        # Without ICU (sudo apt install libicu78), .NET needs invariant globalization; the tests don't notice
        if ! ldconfig -p 2>/dev/null | grep -q libicuuc; then export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1; fi
        run_pester_parallel "$PWSH"
    elif command -v powershell.exe >/dev/null && command -v wslpath >/dev/null; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)" "${only[@]}"
    else
        echo "No PowerShell found; skipping (CI runs it)"
    fi
}
if [ "$BASH_ONLY" = 0 ]; then
    PESTER_LOG=$(mktemp)
    start_pester > "$PESTER_LOG" 2>&1 &
    PESTER_PID=$!
fi


# Run the given test files, or the picked ones
SUITES=()
for file in tests/*.bats; do wanted "$file" && SUITES+=("$file"); done
EXPLICIT=0
for arg in "$@"; do case "$arg" in *.bats) EXPLICIT=1; SUITES=(); break ;; esac; done

echo "== bats"
# bats' own --jobs needs GNU parallel. Files run side by side; tests within a file stay in order
JOBS=()
if command -v parallel >/dev/null; then
    JOBS=(--jobs "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" --no-parallelize-within-files)
fi
if [ "$EXPLICIT" = 1 ] || [ ${#SUITES[@]} -gt 0 ]; then
    "$BATS" "${JOBS[@]}" "$@" "${SUITES[@]}" || FAILED=1
else
    echo "No bats suites needed"
fi

echo "== shellcheck"
if ! wanted shellcheck; then
    echo "No shell scripts changed"
elif command -v shellcheck >/dev/null; then
    shellcheck deploy.sh tests/run.sh tests/lua/run.sh tools/post-game-test-report.sh && shellcheck -s bash tests/*.bash tests/*.bats || FAILED=1
else
    echo "shellcheck not installed; skipping (CI runs it)"
fi

if wanted lua; then tests/lua/run.sh || FAILED=1; else echo "== Lua"; echo "No Lua checks needed"; fi

echo "== Python unit tests"
if [ ${#PYTHON_TESTS[@]} = 0 ]; then
    echo "No Python unit tests needed"
elif [ "$ALL" = 1 ] && command -v python3 >/dev/null; then
    PYTHONPATH=tools python3 -m unittest discover -s tests/python || FAILED=1
elif command -v python3 >/dev/null; then
    PYTHONPATH=tools:tests/python python3 -m unittest "${PYTHON_TESTS[@]}" || FAILED=1
else
    echo "python3 not installed; skipping (CI runs them)"
fi

echo "== Pirate variants"
# The generated variants must match profiles/vanilla/variants.xml: in full with the unpacked game
# files, by profiles/vanilla/variants.manifest without them (as in CI)
if ! wanted variants; then
    echo "No variant changes"
elif command -v python3 >/dev/null; then
    python3 tools/generate_variants.py --check || FAILED=1
else
    echo "python3 not installed; skipping (CI runs it)"
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
