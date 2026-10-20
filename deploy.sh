#!/usr/bin/env bash

# X4 Foundations Mod Deployment Script
# Syncs the mod into <X4_PATH>/extensions/<id>, removing files that are no longer
# part of it. By default it deploys the latest origin/main, not your working tree.
#
# Usage: ./deploy.sh [--ref <git-ref>] [--working-tree] [--set NAME=VALUE]... [--dry-run]

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

die() { echo -e "${RED}Error: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}$*${NC}" >&2; }

usage() {
    cat <<'EOF'
Usage: ./deploy.sh [options]

  --ref <ref>      Deploy this git ref (default: origin/main, fetched first)
  --working-tree   Deploy the files on disk instead, including uncommitted changes
  --set NAME=VALUE Override a setting from md/apirateslife_config.xml in the deployed
                   copy only; repeat it or use commas, e.g. --set IntactOnEject=0,IntactOnClaim=0
  --dry-run        Show what would change without touching the game folder
  -h, --help       Show this help
EOF
}

REF=origin/main
REF_SET=0
WORKING_TREE=0
DRY_RUN=0
SETS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --ref) [ -n "${2:-}" ] || die "--ref needs a value"; REF=$2; REF_SET=1; shift 2 ;;
        --working-tree) WORKING_TREE=1; shift ;;
        --set) [ -n "${2:-}" ] || die "--set needs NAME=VALUE"; SETS+=("$2"); shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
done
[ "$WORKING_TREE" = 1 ] && [ "$REF_SET" = 1 ] && die "--ref and --working-tree can't be combined"

cd "$(dirname "$0")"

# Resolve the X4 install folder: environment first, then deploy.config
if [ -z "${X4_PATH:-}" ]; then
    [ -f deploy.config ] || die "deploy.config not found. Run 'make setup' first to create it from deploy.config.example"
    X4_PATH=$(sed -n 's/^[[:space:]]*X4_PATH[[:space:]]*=[[:space:]]*//p' deploy.config | tail -n 1 | sed 's/[[:space:]]*$//')
    X4_PATH=${X4_PATH#\"}; X4_PATH=${X4_PATH%\"}
    X4_PATH=${X4_PATH#\'}; X4_PATH=${X4_PATH%\'}
fi
[ -n "$X4_PATH" ] || die "X4_PATH not set in deploy.config"
if [[ "$X4_PATH" =~ ^[A-Za-z]:[\\/] ]]; then
    command -v wslpath >/dev/null || die "X4_PATH is a Windows path, but wslpath isn't available to convert it"
    X4_PATH=$(wslpath -u "$X4_PATH")
fi
[ -d "$X4_PATH" ] || die "X4 install folder not found: $X4_PATH"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir "$STAGE/mod"

# Stage the mod files
if [ "$WORKING_TREE" = 1 ]; then
    SOURCE="working tree ($(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no git'))"
    [ -f deploy.include ] || die "deploy.include not found"
    while read -r p; do
        [ -e "$p" ] && cp -R "$p" "$STAGE/mod/"
    done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' deploy.include)
else
    if [ "$REF_SET" = 0 ]; then
        git fetch --quiet origin main || warn "Couldn't fetch origin; deploying the last fetched origin/main"
    fi
    git rev-parse --verify --quiet "$REF^{commit}" >/dev/null || die "unknown git ref: $REF"
    git cat-file -e "$REF:deploy.include" 2>/dev/null || die "$REF has no deploy.include; deploy a newer ref or use --working-tree"
    PATHS=()
    while read -r p; do
        git cat-file -e "$REF:$p" 2>/dev/null && PATHS+=("$p")
    done < <(git show "$REF:deploy.include" | sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d')
    [ ${#PATHS[@]} -gt 0 ] || die "nothing to deploy at $REF"
    git archive --format=tar -o "$STAGE/mod.tar" "$REF" -- "${PATHS[@]}"
    tar -xf "$STAGE/mod.tar" -C "$STAGE/mod"
    SOURCE="$REF @ $(git log -1 --format='%h %s' "$REF")"
fi

[ -f "$STAGE/mod/content.xml" ] || die "content.xml missing from the deployed files"
MOD_ID=$(sed -n 's/.*<content[^>]* id="\([^"]*\)".*/\1/p' "$STAGE/mod/content.xml" | head -n 1)
# The id names a folder we mirror into with deletes, so it must not escape extensions/
[[ "$MOD_ID" =~ ^[A-Za-z0-9_-][A-Za-z0-9_.-]*$ ]] || die "couldn't read a valid extension id from content.xml"
TARGET="$X4_PATH/extensions/$MOD_ID"

# Apply --set overrides to the staged config only; the repo copy is never touched
if [ ${#SETS[@]} -gt 0 ]; then
    CONFIG="$STAGE/mod/md/apirateslife_config.xml"
    [ -f "$CONFIG" ] || die "--set needs md/apirateslife_config.xml in the deployed files"
    # shellcheck disable=SC2016  # the $ is literal: we're matching global.$APiratesLife_ in the XML
    VALID=$(grep -o 'name="global\.\$APiratesLife_[A-Za-z0-9_]*"' "$CONFIG" | sed 's/.*APiratesLife_\([A-Za-z0-9_]*\)"/\1/' | tr '\n' ' ')
    ALL_SETS=()
    for s in "${SETS[@]}"; do
        IFS=',' read -r -a parts <<< "$s"   # allow --set A=0,B=1 as well as repeated --set
        ALL_SETS+=("${parts[@]}")
    done
    for s in "${ALL_SETS[@]}"; do
        [[ "$s" == *=* ]] || die "--set needs NAME=VALUE, got: $s"
        name=${s%%=*}; value=${s#*=}
        if ! [[ "$name" =~ ^[A-Za-z0-9_]+$ ]] || [[ " $VALID" != *" $name "* ]]; then
            die "unknown setting '$name' (valid: ${VALID% })"
        fi
        [[ "$value" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid value for $name: '$value' (letters, digits, '_', '.', '-' only)"
        sed "s|\(name=\"global\.\$APiratesLife_$name\" exact=\"\)[^\"]*\"|\1$value\"|" "$CONFIG" > "$STAGE/config.tmp"
        mv "$STAGE/config.tmp" "$CONFIG"
        SET_SUMMARY="${SET_SUMMARY:+$SET_SUMMARY, }$name=$value"
    done
fi

echo -e "${GREEN}Deploying $SOURCE${NC}"
echo "  to $TARGET"
[ -n "${SET_SUMMARY:-}" ] && echo "  with settings: $SET_SUMMARY"
[ "$DRY_RUN" = 1 ] && warn "Dry run: nothing will be changed"

# Mirror the staged files into the target, deleting anything that's no longer in the mod
if command -v rsync >/dev/null; then
    RSYNC_OPTS=(-rc --delete --out-format='  %o %n')
    [ "$DRY_RUN" = 1 ] && RSYNC_OPTS+=(-n)
    [ "$DRY_RUN" = 1 ] || mkdir -p "$TARGET"
    rsync "${RSYNC_OPTS[@]}" "$STAGE/mod/" "$TARGET/" > "$STAGE/changes"
    grep -v '/$' "$STAGE/changes" || echo "  (already up to date)"
else
    if [ "$DRY_RUN" = 1 ]; then
        (cd "$STAGE/mod" && find . -type f | sed 's|^\./|  copy |')
    else
        rm -rf "$TARGET"
        mkdir -p "$TARGET"
        cp -R "$STAGE/mod/." "$TARGET/"
        (cd "$TARGET" && find . -type f | sed 's|^\./|  copied |')
    fi
fi

[ "$DRY_RUN" = 1 ] || echo -e "${GREEN}Deployment successful!${NC} Restart X4 to pick up changes."
