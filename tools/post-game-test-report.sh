#!/usr/bin/env bash

# Posts the last game-test report (tests/game/report.md, written by make game-test) to this
# branch's PR: as a comment, plus a "game-tests" commit status on the tested commit, so the
# result shows in the PR's checks. Refuses unless the report is for exactly the PR's latest
# commit, with no uncommitted changes in the run.
#
# Usage: tools/post-game-test-report.sh [--dry-run] [--report <file>]
#   --dry-run  check everything and print what would be posted, without posting
#
# Needs git and an authenticated gh (gh auth login).

set -euo pipefail

cd "$(dirname "$0")/.."

REPORT=tests/game/report.md
DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --report) REPORT="$2"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "Not posted: $*" >&2; exit 1; }

[ -f "$REPORT" ] || die "no report at $REPORT; run make game-test first"
marker=$(grep -m 1 '^<!-- apirateslife-game-tests ' "$REPORT" || true)
[ -n "$marker" ] || die "$REPORT isn't a game-test report"

field() { sed -n "s/.* $1=\([^ ]*\).*/\1/p" <<<"$marker"; }
commit=$(field commit)
dirty=$(field dirty)
result=$(field result)
passed=$(field passed)
total=$(field total)

[ "$dirty" = false ] || die "the run included uncommitted changes. Commit them, push, and run make game-test again"
head=$(git rev-parse HEAD)
[ "$commit" = "$head" ] || die "the report is for ${commit:0:7}, but HEAD is ${head:0:7}. Run make game-test again"

pr=$(gh pr view --json number,headRefOid,state --jq '"\(.number) \(.headRefOid) \(.state)"' 2>/dev/null) ||
    die "no PR found for this branch; open one first (gh pr create)"
read -r number pr_head state <<<"$pr"
[ "$state" = OPEN ] || die "PR #$number is $state"
[ "$pr_head" = "$commit" ] || die "PR #$number's latest commit is ${pr_head:0:7}, not the tested ${commit:0:7}. Push your branch, or test the PR's commit"

if [ "$result" = pass ]; then status=success; else status=failure; fi
description="$passed of $total passed (local run)"

if [ "$DRY_RUN" = 1 ]; then
    echo "Would comment on PR #$number and set game-tests=$status ($description) on ${commit:0:7}:"
    echo
    cat "$REPORT"
    exit 0
fi

gh pr comment "$number" --body-file "$REPORT"
gh api --silent "repos/{owner}/{repo}/statuses/$commit" \
    -f state="$status" -f context=game-tests -f description="$description"
echo "Posted to PR #$number: game-tests $status ($description) on ${commit:0:7}"
