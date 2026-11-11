#!/usr/bin/env bash
# Lists every worktree of this repo and flags work that could be lost: uncommitted changes, or
# commits on no remote whose changes haven't reached origin/main. Squash merges leave a branch's
# own commits behind forever, so whether work landed is checked by content (the branch's changes
# are already in origin/main), then by a merged PR for the branch when gh is available.
#
# Usage: tools/worktree-status.sh [--hook]
#   (no option)  one line per worktree; exits 1 when any worktree has work at risk
#   --hook       for a SessionStart hook: prints a JSON message only when work is at risk, exits 0
# Environment: WORKTREE_STATUS_MAIN (default origin/main), WORKTREE_STATUS_NO_GH=1 skips gh.
set -euo pipefail

mode=${1:-}
main_ref=${WORKTREE_STATUS_MAIN:-origin/main}
top=$(git rev-parse --show-toplevel)
common=$(git rev-parse --git-common-dir)
main_checkout=$(cd "$top" && cd "$(dirname "$(cd "$top" && realpath "$common")")" && pwd)

# landed <path>: the worktree branch's changes since it left main are all in main already
landed() {
    local base idx ok=1
    base=$(git -C "$1" merge-base HEAD "$main_ref" 2>/dev/null) || return 1
    git -C "$1" diff --quiet "$base" HEAD && return 0
    idx=$(mktemp)
    GIT_INDEX_FILE=$idx git -C "$1" read-tree "$main_ref"
    if git -C "$1" diff "$base" HEAD | GIT_INDEX_FILE=$idx git -C "$1" apply --cached -R --check 2>/dev/null; then
        ok=0
    fi
    rm -f "$idx"
    return $ok
}

# merged_pr <branch>: GitHub has a merged PR from this branch
merged_pr() {
    [ -z "${WORKTREE_STATUS_NO_GH:-}" ] && [ -n "$1" ] && command -v gh >/dev/null || return 1
    [ -n "$(gh pr list --head "$1" --state merged --json number --jq '.[0].number' 2>/dev/null)" ]
}

risk=()
lines=()
while IFS= read -r line; do
    case $line in worktree\ *) ;; *) continue ;; esac
    path=${line#worktree }
    branch=$(git -C "$path" branch --show-current)
    name=${branch:-(detached)}
    dirty=$(git -C "$path" status --porcelain | wc -l)
    local_commits=$(git -C "$path" rev-list --count HEAD --not --remotes)
    if [ "$dirty" -gt 0 ]; then
        state="UNCOMMITTED: $dirty changed files"
    elif landed "$path"; then
        state="on $main_ref"
        [ "$path" != "$main_checkout" ] && state="$state, can be removed"
    elif merged_pr "$branch"; then
        state="PR merged, can be removed"
    elif [ "$local_commits" -gt 0 ]; then
        state="UNPUSHED: $local_commits commits not on any remote or $main_ref"
    else
        state="pushed"
    fi
    lines+=("$path | $name | $state")
    case $state in UNCOMMITTED* | UNPUSHED*) risk+=("$path ($name): $state") ;; esac
done < <(git worktree list --porcelain)

if [ "$mode" = "--hook" ]; then
    [ ${#risk[@]} -eq 0 ] && exit 0
    msg="Worktrees with work that could be lost (tools/worktree-status.sh):"
    for r in "${risk[@]}"; do msg+=$'\n'"- $r"; done
    python3 -c 'import json, sys; m = sys.argv[1]; print(json.dumps({"systemMessage": m, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": m}}))' "$msg"
    exit 0
fi

printf '%s\n' "${lines[@]}"
[ ${#risk[@]} -eq 0 ]
