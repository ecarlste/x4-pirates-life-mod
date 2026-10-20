#!/usr/bin/env bash

# Runs every test suite available on this machine:
#   - bats suites for deploy.sh and the Makefile (bats-core is fetched into .tools/ on first run)
#   - shellcheck, when installed
#   - the Pester suites, through pwsh or (under WSL) Windows PowerShell
#
# Usage: tests/run.sh [--bash-only] [bats args...]

set -eo pipefail

BATS_VERSION=v1.11.1

cd "$(dirname "$0")/.."

BASH_ONLY=0
if [ "${1:-}" = --bash-only ]; then BASH_ONLY=1; shift; fi

BATS=.tools/bats-core-$BATS_VERSION/bin/bats
if [ ! -x "$BATS" ]; then
    echo "Fetching bats-core $BATS_VERSION into .tools/"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$BATS_VERSION" \
        https://github.com/bats-core/bats-core.git ".tools/bats-core-$BATS_VERSION"
fi

FAILED=0

# Run the given test files, or every suite when none are named
SUITES=(tests/*.bats)
for arg in "$@"; do case "$arg" in *.bats) SUITES=(); break ;; esac; done

echo "== bats"
"$BATS" "$@" "${SUITES[@]}" || FAILED=1

echo "== shellcheck"
if command -v shellcheck >/dev/null; then
    shellcheck deploy.sh tests/run.sh tools/post-game-test-report.sh && shellcheck -s bash tests/*.bash tests/*.bats || FAILED=1
else
    echo "shellcheck not installed; skipping (CI runs it)"
fi

if [ "$BASH_ONLY" = 0 ]; then
    echo "== Pester"
    if command -v pwsh >/dev/null; then
        pwsh -NoProfile -File tests/run.ps1 || FAILED=1
    elif command -v powershell.exe >/dev/null && command -v wslpath >/dev/null; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w tests/run.ps1)" || FAILED=1
    else
        echo "No PowerShell found; skipping (CI runs it)"
    fi
fi

exit "$FAILED"
