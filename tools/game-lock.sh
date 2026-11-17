#!/usr/bin/env bash
# The game lock: only one game run (or deploy into the game) at a time, across this
# repo and the bounty hunter's. The lock is the file <X4_PATH>/game.lock; its format and rules are
# in tools/README.md ("The game lock"). tools/game-lock.ps1 is the PowerShell twin.
#
# Sourced by deploy.sh for its functions:
#   game_lock_acquire FILE WHAT   join the line, take the lock in turn; returns 1 if it can't
#   game_lock_release             let it go (only if this script took it)
#   x4_path_resolve ROOT          set X4_PATH from the environment, else deploy.config (tools/deploy-config.sh)
#
# Run, it holds the lock around a command, e.g. make game-test's deploy and run:
#   tools/game-lock.sh [--what NAME] -- command [args...]
# The command gets X4_GAME_LOCK_TOKEN (also passed on to Windows programs through WSLENV), so a
# deploy or runner it starts uses the lock it was handed instead of waiting for it.
#
# Run with --queue, it prints the holder and the line, changing nothing (make game-queue):
#   tools/game-lock.sh --queue
#
# Waiters take the lock in the order they arrived: each joins the line, a numbered ticket in
# <X4_PATH>/game.queue, and only the first in line takes the lock (tools/README.md, "The line").
#
# Environment: X4_GAME_LOCK_WAIT  seconds to wait in line (unset: no limit; 0 refuses at once if
#                                 the lock is held or anyone is in line)
#              X4_GAME_LOCK_STALE seconds a lock or ticket may go unchanged before it counts as
#                                 crashed: the first in line takes over such a lock, and a waiter
#                                 drops such a ticket ahead of it (default 60; keep it the same in
#                                 both repos, since a holder beats every STALE/6 s)
#              X4_GAME_LOCK_POLL  seconds between checks while waiting (default 5)

# shellcheck source=tools/deploy-config.sh
. "$(dirname "${BASH_SOURCE[0]}")/deploy-config.sh"

GAME_LOCK_FILE=''
GAME_LOCK_HEARTBEAT_PID=''
GAME_LOCK_TICKET=''
GAME_LOCK_GONE=$'\x01gone'  # what a waiter has seen of a lock file that isn't there

# Sets X4_PATH (a WSL path if it was a Windows one) from the environment, else deploy.config: the
# checkout's own, else the main checkout's (tools/deploy-config.sh)
x4_path_resolve() {
    local root=$1
    if [ -z "${X4_PATH:-}" ]; then
        [ -n "$(deploy_config_files "$root")" ] || { echo "deploy.config not found. Run 'make setup' first to create it from deploy.config.example" >&2; return 1; }
        X4_PATH=$(deploy_config_value "$root" X4_PATH)
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

# Who holds the lock file $1, for messages; for one with no token in it (a crashed or interrupted
# write), "an empty lock file" or "an unreadable lock file"
_game_lock_who() {
    if [ -n "$(_game_lock_field "$1" token)" ]; then _game_lock_holder "$1"
    elif [ -s "$1" ]; then echo 'an unreadable lock file'
    else echo 'an empty lock file'
    fi
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

# Writes the lock's lines to $1 (the lock, or this waiter's ticket), with heartbeat number $2: to a
# file beside it first, then moved over it, so a waiter reading it sees the old or the new lines,
# never an empty or half-written file. Returns 1 if it can't; callers retry: the first write at once
# (_game_lock_write_first), the rest next time
_game_lock_replace() {
    local tmp="$1.$BASHPID.tmp"
    if _game_lock_write "$1" "$2" >| "$tmp" && mv -f "$tmp" "$1"; then return 0; fi
    rm -f "$tmp"
    return 1
}

# Writes newly taken lock $1's first lines. A waiter on Windows watching it may have it open right
# now, and on drvfs that makes the rename fail, so it retries for about a second; past that it
# returns 1, failing the run (callers run it left of ||, so set -e can't), and the empty lock goes
# stale for the next in line to take over after $2 s, as with tools/game-lock.ps1
_game_lock_write_first() {
    local try err
    for (( try = 1; ; try++ )); do
        err=$(_game_lock_replace "$1" 0 2>&1) && return 0
        if [ "$try" -ge 50 ]; then
            echo "Took the game lock ($1) but couldn't write its first lines${err:+: $err}. It's left empty, so the next in line takes it over once it has sat unchanged for $2 s" >&2
            return 1
        fi
        sleep 0.02
    done
}

# The tickets in the line in $1, in line order (the zero-padded numbers sort)
_game_lock_tickets() {
    local t
    for t in "$1"/[0-9][0-9][0-9][0-9][0-9][0-9]; do
        [ -e "$t" ] && printf '%s\n' "$t"
    done
}

# Joins the line in $1: the next number, created exclusively, so two joiners never share one.
# Sets GAME_LOCK_TICKET
_game_lock_join() {
    local queue=$1 last n
    mkdir -p "$queue" 2>/dev/null || [ -d "$queue" ] || return 1
    while :; do
        last=$(_game_lock_tickets "$queue" | tail -n 1)
        last=${last##*/}
        n=$(( ${last:+10#$last} + 1 ))
        printf -v GAME_LOCK_TICKET '%s/%06d' "$queue" "$n"
        (set -o noclobber; : > "$GAME_LOCK_TICKET") 2>/dev/null && return 0
    done
}

# 1st, 2nd, 3rd, 4th, ..., 11th, 12th, 13th, ..., 21st
_game_lock_ordinal() {
    local n=$1 suffix=th
    case $(( n % 100 )) in
        11|12|13) ;;
        *) case $(( n % 10 )) in 1) suffix=st ;; 2) suffix=nd ;; 3) suffix=rd ;; esac ;;
    esac
    echo "$n$suffix"
}

# Who holds the lock $1, or "free"
_game_lock_held() {
    if [ -e "$1" ]; then echo "held by $(_game_lock_who "$1")"; else echo free; fi
}

# The waiters named by ticket files $@, for messages: "A", "A and B", "A; B and C"
_game_lock_names() {
    local out='' name i
    for (( i = 1; i <= $#; i++ )); do
        name=$(_game_lock_holder "${!i}")
        if [ "$i" -eq 1 ]; then out=$name; elif [ "$i" -eq $# ]; then out+=" and $name"; else out+="; $name"; fi
    done
    echo "$out"
}

# Removes this waiter's ticket, if it has one
_game_lock_leave() {
    [ -n "$GAME_LOCK_TICKET" ] && rm -f "$GAME_LOCK_TICKET"
    GAME_LOCK_TICKET=''
}

game_lock_acquire() {
    local file=$1 what=$2
    local wait=${X4_GAME_LOCK_WAIT:-} stale=${X4_GAME_LOCK_STALE:-60} poll=${X4_GAME_LOCK_POLL:-5}
    local queue started seen=$GAME_LOCK_GONE seen_at=$SECONDS shown='' current msg t place beat=0 behind
    local -a ahead
    local -A ticket_seen=() ticket_at=()
    [[ ( -z "$wait" || "$wait" =~ ^[0-9]+$ ) && "$stale" =~ ^[0-9]+$ ]] || { echo "X4_GAME_LOCK_WAIT and X4_GAME_LOCK_STALE take whole seconds" >&2; return 1; }

    # A lock handed down by a caller that holds it (make game-test): use it, don't join the line
    if [ -n "${X4_GAME_LOCK_TOKEN:-}" ] && [ "$(_game_lock_field "$file" token)" = "$X4_GAME_LOCK_TOKEN" ]; then
        return 0
    fi

    # Join the line, always, even when it's empty and the lock is free: one way in
    queue="$(dirname "$file")/game.queue"
    X4_GAME_LOCK_TOKEN="$$-$RANDOM$RANDOM-$(date +%s)"
    export X4_GAME_LOCK_TOKEN
    GAME_LOCK_WHAT=$what GAME_LOCK_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _game_lock_join "$queue" || { echo "Can't join the game lock's line in $queue" >&2; return 1; }
    started=$SECONDS

    while :; do
        # Stay in line: rewrite the ticket, so the waiters behind can tell it from a crashed one
        _game_lock_replace "$GAME_LOCK_TICKET" "$beat" || true  # a reader holding it open; the next poll will do
        beat=$((beat + 1))

        # The tickets ahead; drop one that stopped changing (its waiter crashed)
        ahead=()
        while IFS= read -r t; do
            [[ "${t##*/}" < "${GAME_LOCK_TICKET##*/}" ]] || continue
            current=$(cat "$t" 2>/dev/null) || continue
            if [ "${ticket_seen[$t]+set}" != set ] || [ "${ticket_seen[$t]}" != "$current" ]; then
                ticket_seen[$t]=$current ticket_at[$t]=$SECONDS
            elif [ $(( SECONDS - ticket_at[$t] )) -ge "$stale" ] && [ "$(cat "$t" 2>/dev/null)" = "$current" ]; then
                # Only if it's still the same text, as with the lock
                echo "Dropping $(_game_lock_holder "$t") from the game lock's line: its ticket hasn't changed for ${stale} s, so it looks crashed" >&2
                rm -f "$t"
                continue
            fi
            ahead+=("$t")
        done < <(_game_lock_tickets "$queue")

        # The lock: watched by every waiter, acted on only by the first in line. An empty lock (a
        # crashed or interrupted write) is text like any other, so it goes stale too; a missing one
        # is marked apart, so a holder that has just created the file isn't taken for an empty lock
        current=$(cat "$file" 2>/dev/null) || current=$GAME_LOCK_GONE
        if [ "$current" != "$seen" ]; then
            seen=$current seen_at=$SECONDS
        fi
        if [ ${#ahead[@]} -eq 0 ]; then
            # noclobber makes the create exclusive: an old taker that skips the line may beat us
            if (set -o noclobber; : > "$file") 2>/dev/null; then
                GAME_LOCK_FILE=$file GAME_LOCK_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                _game_lock_write_first "$file" "$stale" || { _game_lock_leave; return 1; }
                _game_lock_leave
                # The heartbeat: rewrite the file while this script lives, so waiters can tell a
                # crashed holder (its file stops changing) from a long run
                local every=$(( stale / 6 )) holder_pid=$$
                [ "$every" -ge 1 ] || every=1
                (
                    n=0
                    while sleep "$every" && kill -0 "$holder_pid" 2>/dev/null; do
                        n=$((n + 1))
                        [ "$(_game_lock_field "$file" token)" = "$X4_GAME_LOCK_TOKEN" ] || break
                        _game_lock_replace "$file" "$n" || true  # a reader holding it open; the next beat will do
                    done
                ) >/dev/null 2>&1 &
                GAME_LOCK_HEARTBEAT_PID=$!
                behind=$(_game_lock_tickets "$queue" | wc -l)
                [ "$behind" -eq 0 ] || echo "Took the game lock; $behind waiting behind you; keep this run short" >&2
                return 0
            fi
            if [ "$seen" != "$GAME_LOCK_GONE" ] && [ $(( SECONDS - seen_at )) -ge "$stale" ] \
                && current=$(cat "$file" 2>/dev/null) && [ "$current" = "$seen" ]; then
                # Only if it's still the same text (a failed read isn't): an old taker may have taken
                # it over just now
                echo "Taking over the game lock: $(_game_lock_who "$file") hasn't updated it for ${stale} s, so it looks crashed" >&2
                rm -f "$file"
                continue
            fi
            # Freed just now: try again at once
            [ -e "$file" ] || continue
        fi

        place=$(_game_lock_ordinal $(( ${#ahead[@]} + 1 )))
        if [ ${#ahead[@]} -gt 0 ]; then place+=" in line, behind $(_game_lock_names "${ahead[@]}")"; else place+=' in line'; fi
        msg="$place; $(_game_lock_held "$file")"
        if [ "$wait" = 0 ] || { [ -n "$wait" ] && [ $(( SECONDS - started )) -ge "$wait" ]; }; then
            echo "The game lock ($file) isn't yours yet: $(_game_lock_held "$file")${ahead[*]:+, with ${#ahead[@]} in line ahead of you: $(_game_lock_names "${ahead[@]}")}. Try again when they're done (make game-queue shows the line); a crashed run's lock or ticket frees itself ${stale} s after its last update" >&2
            _game_lock_leave
            return 1
        fi
        if [ "$msg" != "$shown" ]; then
            shown=$msg
            echo "Waiting for the game lock: $msg" >&2
        fi
        sleep "$poll"
    done
}

game_lock_release() {
    _game_lock_leave
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

# How long ago UTC time $1 was, by this machine's clock: "3 s", "4 min 12 s", "2 h 5 min", "1 d 3 h"
_game_lock_age() {
    local at secs
    at=$(date -u -d "$1" +%s 2>/dev/null) || { echo '?'; return; }
    secs=$(( $(date -u +%s) - at ))
    [ "$secs" -ge 0 ] || secs=0
    if [ "$secs" -lt 60 ]; then echo "$secs s"
    elif [ "$secs" -lt 3600 ]; then echo "$(( secs / 60 )) min $(( secs % 60 )) s"
    elif [ "$secs" -lt 86400 ]; then echo "$(( secs / 3600 )) h $(( secs % 3600 / 60 )) min"
    else echo "$(( secs / 86400 )) d $(( secs % 86400 / 3600 )) h"
    fi
}

# Prints the holder of lock $1 and the line beside it, changing nothing (make game-queue)
game_lock_show() {
    local file=$1 t i=0 beat
    local -a line=()
    while IFS= read -r t; do line+=("$t"); done < <(_game_lock_tickets "$(dirname "$file")/game.queue")
    if [ ! -e "$file" ] && [ ${#line[@]} -eq 0 ]; then
        echo "The game lock ($file) is free, nobody waiting"
        return 0
    fi
    if [ -e "$file" ] && [ -z "$(_game_lock_field "$file" token)" ]; then
        echo "The game lock ($file) is $(_game_lock_who "$file"), unchanged for $(_game_lock_age "@$(stat -c %Y "$file")"): the first in line takes it over once it has been unchanged for ${X4_GAME_LOCK_STALE:-60} s"
    elif [ -e "$file" ]; then
        beat=$(_game_lock_field "$file" heartbeat)
        echo "The game lock ($file) is held by $(_game_lock_holder "$file"): for $(_game_lock_age "$(_game_lock_field "$file" started)"), last heartbeat $(_game_lock_age "${beat#* }") ago"
    else
        echo "The game lock ($file) is free"
    fi
    if [ ${#line[@]} -eq 0 ]; then
        echo "In line: nobody waiting"
        return 0
    fi
    echo "In line: ${#line[@]} waiting, first in line first"
    for t in "${line[@]}"; do
        i=$((i + 1))
        beat=$(_game_lock_field "$t" heartbeat)
        echo "  $i. $(_game_lock_holder "$t"): waiting $(_game_lock_age "$(_game_lock_field "$t" started)"), last heartbeat $(_game_lock_age "${beat#* }") ago"
    done
}

# Run as a command: hold the lock around one
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -eo pipefail
    what='command'
    while [ $# -gt 0 ]; do
        case "$1" in
            --queue)
                x4_path_resolve "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
                game_lock_show "$X4_PATH/game.lock"
                exit ;;
            --what) what=${2:?--what needs a name}; shift 2 ;;
            --) shift; break ;;
            *) break ;;
        esac
    done
    [ $# -gt 0 ] || { echo "Usage: tools/game-lock.sh [--what NAME] -- command [args...]   or   tools/game-lock.sh --queue" >&2; exit 2; }
    x4_path_resolve "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
    trap game_lock_release EXIT
    game_lock_acquire "$X4_PATH/game.lock" "$what" || exit 1
    # Windows programs started from WSL (the game-test runner) only see variables listed in WSLENV
    case ":${WSLENV:-}:" in *:X4_GAME_LOCK_TOKEN:*) ;; *) export WSLENV="X4_GAME_LOCK_TOKEN${WSLENV:+:$WSLENV}" ;; esac
    status=0
    "$@" || status=$?
    exit "$status"
fi
