#!/usr/bin/env bash
# The game lock: only one game run (or deploy into the game) at a time, across this
# repo and the bounty hunter's. The lock is the file <X4_PATH>/game.lock; its format and rules are
# in tools/README.md ("The game lock"). tools/game-lock.ps1 is the PowerShell twin.
#
# Sourced by deploy.sh for its functions:
#   game_lock_acquire FILE WHAT   take the lock, waiting for another holder; returns 1 if it can't
#   game_lock_release             let it go (only if this script took it)
#   x4_path_resolve ROOT          set X4_PATH from the environment or ROOT/deploy.config
#
# Run, it holds the lock around a command, e.g. make game-test's deploy and run:
#   tools/game-lock.sh [--what NAME] -- command [args...]
# The command gets X4_GAME_LOCK_TOKEN (also passed on to Windows programs through WSLENV), so a
# deploy or runner it starts uses the lock it was handed instead of waiting for it.
#
# Environment: X4_GAME_LOCK_WAIT  seconds to wait for another holder (default 1800; 0 refuses at once)
#              X4_GAME_LOCK_STALE seconds a holder's lock may go unchanged before it counts as
#                                 crashed and is taken over (default 60; keep it the same in
#                                 both repos, since a holder beats every STALE/6 s)
#              X4_GAME_LOCK_POLL  seconds between checks while waiting (default 5)

GAME_LOCK_FILE=''
GAME_LOCK_HEARTBEAT_PID=''

# Sets X4_PATH (a WSL path if it was a Windows one) from the environment, else ROOT/deploy.config
x4_path_resolve() {
    local root=$1
    if [ -z "${X4_PATH:-}" ]; then
        [ -f "$root/deploy.config" ] || { echo "deploy.config not found. Run 'make setup' first to create it from deploy.config.example" >&2; return 1; }
        X4_PATH=$(sed -n 's/^[[:space:]]*X4_PATH[[:space:]]*=[[:space:]]*//p' "$root/deploy.config" | tail -n 1 | sed 's/[[:space:]]*$//')
        X4_PATH=${X4_PATH#\"}; X4_PATH=${X4_PATH%\"}
        X4_PATH=${X4_PATH#\'}; X4_PATH=${X4_PATH%\'}
    fi
    [ -n "$X4_PATH" ] || { echo "X4_PATH not set in deploy.config" >&2; return 1; }
    if [[ "$X4_PATH" =~ ^[A-Za-z]:[\\/] ]]; then
        command -v wslpath >/dev/null || { echo "X4_PATH is a Windows path, but wslpath isn't available to convert it" >&2; return 1; }
        X4_PATH=$(wslpath -u "$X4_PATH")
    fi
    [ -d "$X4_PATH" ] || { echo "X4 install folder not found: $X4_PATH" >&2; return 1; }
    export X4_PATH
}

# One value from a lock file's KEY=value lines
_game_lock_field() {
    sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1
}

# Who holds the lock, for messages
_game_lock_holder() {
    local f=$1
    printf '%s (%s, %s), pid %s on %s, since %s' \
        "$(_game_lock_field "$f" what)" "$(_game_lock_field "$f" repo)" "$(_game_lock_field "$f" branch)" \
        "$(_game_lock_field "$f" pid)" "$(_game_lock_field "$f" host)" "$(_game_lock_field "$f" started)"
}

# Writes the lock file's lines, with heartbeat number $2
_game_lock_write() {
    local repo branch host
    repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')
    host=linux
    [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] && host=wsl
    printf 'token=%s\nwhat=%s\nrepo=%s\nbranch=%s\npid=%s\nhost=%s\nstarted=%s\nheartbeat=%s %s\n' \
        "$X4_GAME_LOCK_TOKEN" "$GAME_LOCK_WHAT" "$repo" "$branch" "$$" "$host" "$GAME_LOCK_STARTED" \
        "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

game_lock_acquire() {
    local file=$1 what=$2
    local wait=${X4_GAME_LOCK_WAIT:-1800} stale=${X4_GAME_LOCK_STALE:-60} poll=${X4_GAME_LOCK_POLL:-5}
    local started=$SECONDS seen='' seen_at=$SECONDS holder='' current now
    [[ "$wait" =~ ^[0-9]+$ && "$stale" =~ ^[0-9]+$ ]] || { echo "X4_GAME_LOCK_WAIT and X4_GAME_LOCK_STALE take whole seconds" >&2; return 1; }

    # A lock handed down by a caller that holds it (make game-test): use it, don't wait for it
    if [ -n "${X4_GAME_LOCK_TOKEN:-}" ] && [ "$(_game_lock_field "$file" token)" = "$X4_GAME_LOCK_TOKEN" ]; then
        return 0
    fi

    while :; do
        # noclobber makes the create exclusive: only one taker wins
        if (set -o noclobber; : > "$file") 2>/dev/null; then
            X4_GAME_LOCK_TOKEN="$$-$RANDOM$RANDOM-$(date +%s)"
            export X4_GAME_LOCK_TOKEN
            GAME_LOCK_FILE=$file GAME_LOCK_WHAT=$what GAME_LOCK_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            _game_lock_write "$file" 0 >| "$file"
            # The heartbeat: rewrite the file while this script lives, so waiters can tell a
            # crashed holder (its file stops changing) from a long run
            local beat=$(( stale / 6 )) holder_pid=$$
            [ "$beat" -ge 1 ] || beat=1
            (
                n=0
                while sleep "$beat" && kill -0 "$holder_pid" 2>/dev/null; do
                    n=$((n + 1))
                    [ "$(_game_lock_field "$file" token)" = "$X4_GAME_LOCK_TOKEN" ] || break
                    _game_lock_write "$file" "$n" >| "$file"
                done
            ) >/dev/null 2>&1 &
            GAME_LOCK_HEARTBEAT_PID=$!
            return 0
        fi

        current=$(cat "$file" 2>/dev/null) || current=''
        if [ "$current" != "$seen" ]; then
            seen=$current seen_at=$SECONDS
        elif [ $(( SECONDS - seen_at )) -ge "$stale" ]; then
            # Only if it's still the same text: another waiter may have taken it over just now
            if [ "$(cat "$file" 2>/dev/null)" = "$seen" ]; then
                echo "Taking over the game lock: $(_game_lock_holder "$file") hasn't updated it for ${stale} s, so it looks crashed" >&2
                rm -f "$file"
            fi
            seen='' seen_at=$SECONDS
            continue
        fi

        now=$(_game_lock_holder "$file")
        if [ "$now" != "$holder" ]; then
            holder=$now
            [ "$wait" -gt 0 ] && echo "Waiting for the game lock ($file): held by $holder" >&2
        fi
        if [ $(( SECONDS - started )) -ge "$wait" ]; then
            echo "The game lock ($file) is held by $holder. Try again when it's done; if that run crashed, the lock frees itself ${stale} s after its last update" >&2
            return 1
        fi
        sleep "$poll"
    done
}

game_lock_release() {
    [ -n "$GAME_LOCK_FILE" ] || return 0
    if [ -n "$GAME_LOCK_HEARTBEAT_PID" ]; then
        kill "$GAME_LOCK_HEARTBEAT_PID" 2>/dev/null || true
        wait "$GAME_LOCK_HEARTBEAT_PID" 2>/dev/null || true
    fi
    if [ "$(_game_lock_field "$GAME_LOCK_FILE" token)" = "$X4_GAME_LOCK_TOKEN" ]; then
        rm -f "$GAME_LOCK_FILE"
    fi
    GAME_LOCK_FILE='' GAME_LOCK_HEARTBEAT_PID=''
    return 0
}

# Run as a command: hold the lock around one
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -eo pipefail
    what='command'
    while [ $# -gt 0 ]; do
        case "$1" in
            --what) what=${2:?--what needs a name}; shift 2 ;;
            --) shift; break ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || { echo "Usage: tools/game-lock.sh [--what NAME] -- command [args...]" >&2; exit 2; }
    x4_path_resolve "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
    trap game_lock_release EXIT
    game_lock_acquire "$X4_PATH/game.lock" "$what" || exit 1
    # Windows programs started from WSL (the game-test runner) only see variables listed in WSLENV
    case ":${WSLENV:-}:" in *:X4_GAME_LOCK_TOKEN:*) ;; *) export WSLENV="X4_GAME_LOCK_TOKEN${WSLENV:+:$WSLENV}" ;; esac
    status=0
    "$@" || status=$?
    exit "$status"
fi
