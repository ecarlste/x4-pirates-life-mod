#!/usr/bin/env bash

# Builds the release zip (make release; docs/releasing.md has the whole flow). From the latest
# origin/main, or a given tag, it builds dist/<id>-<version>.zip: one top-level <id>/ folder holding
# the deploy.include paths, LICENSE, CHANGELOG.md and the player files in release/ (README.txt,
# CREDITS.txt). Loose files, no catalog. It writes the release checklist next to it
# (dist/<id>-<version>-checklist.md, tools/test_plan_docs.py --checklist).
#
# The version is content.xml's (version="100" is 1.00) and its tag is v<version>. It refuses:
#   - unless every test suite passes, run in a clean checkout of that commit (RELEASE_TEST, default
#     tests/run.sh --all, is the command run there);
#   - if the tag v<version> exists on a different commit, or a given tag holds another version;
#   - if CHANGELOG.md has no "## <version>" section, or a release file is missing.
#
# Usage: tools/release.sh [--tag v<version>]

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}Error: $*${NC}" >&2; exit 1; }
warn() { echo -e "${YELLOW}$*${NC}" >&2; }

usage() {
    cat <<'EOF'
Usage: tools/release.sh [options]

  --tag <tag>  Build this tag, v<version> (default: the latest origin/main, fetched first)
  -h, --help   Show this help
EOF
}

# The files the zip ships besides the mod, by their path in the repo; each lands in the top-level
# folder under its own name
RELEASE_FILES=(LICENSE CHANGELOG.md release/README.txt release/CREDITS.txt)

TAG=
while [ $# -gt 0 ]; do
    case "$1" in
        --tag) [ -n "${2:-}" ] || die "--tag needs a value"; TAG=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; echo -e "${RED}Error: unknown option: $1${NC}" >&2; exit 2 ;;
    esac
done

cd "$(dirname "$0")/.."
REPO=$PWD

# What to build
if [ -n "$TAG" ]; then
    git fetch --quiet --tags origin || warn "Couldn't fetch origin; using the tags fetched last"
    git rev-parse --verify --quiet "refs/tags/$TAG^{commit}" >/dev/null || die "no tag $TAG"
    REF=refs/tags/$TAG
    NAME=$TAG
else
    git fetch --quiet --tags origin main || warn "Couldn't fetch origin; building the last fetched origin/main"
    REF=origin/main
    NAME=origin/main
fi
COMMIT=$(git rev-parse "$REF^{commit}")
SHORT=$(git rev-parse --short "$COMMIT")

# The version and id, from content.xml
CONTENT=$(git show "$COMMIT:content.xml" 2>/dev/null) || die "$NAME has no content.xml"
RAW=$(sed -n 's/.*<content[^>]* version="\([0-9]*\)".*/\1/p' <<< "$CONTENT" | head -n 1)
[ -n "$RAW" ] || die "couldn't read a version from content.xml at $NAME"
VERSION="$((10#$RAW / 100)).$(printf '%02d' $((10#$RAW % 100)))"
MOD_ID=$(sed -n 's/.*<content[^>]* id="\([^"]*\)".*/\1/p' <<< "$CONTENT" | head -n 1)
[[ "$MOD_ID" =~ ^[A-Za-z0-9_-][A-Za-z0-9_.-]*$ ]] || die "couldn't read a valid extension id from content.xml at $NAME"
VERSION_TAG=v$VERSION

[ -z "$TAG" ] || [ "$TAG" = "$VERSION_TAG" ] || die "$TAG's content.xml says $VERSION, so its tag would be $VERSION_TAG"
if TAGGED=$(git rev-parse --verify --quiet "refs/tags/$VERSION_TAG^{commit}"); then
    [ "$TAGGED" = "$COMMIT" ] || die "$VERSION_TAG is on $(git rev-parse --short "$TAGGED"), not $NAME ($SHORT): bump the version in content.xml, or build the tag (--tag $VERSION_TAG)"
fi

for f in "${RELEASE_FILES[@]}"; do
    git cat-file -e "$COMMIT:$f" 2>/dev/null || die "$f is missing at $NAME"
done
git show "$COMMIT:CHANGELOG.md" | grep -Eq "^## ${VERSION//./\\.}( |$)" || die "CHANGELOG.md has no '## $VERSION' section at $NAME"

echo -e "${GREEN}Releasing $MOD_ID $VERSION from $NAME ($SHORT $(git log -1 --format=%s "$COMMIT"))${NC}"

# Run the tests in a clean checkout of the commit. It sits inside this checkout so Node finds its
# node_modules, and shares .tools/ so the test tools aren't fetched again
STAGE=$(mktemp -d)
CHECKOUT="$REPO/.claude/worktrees/release-$VERSION-$$"
cleanup() {
    git -C "$REPO" worktree remove --force "$CHECKOUT" 2>/dev/null || true
    rm -rf "$STAGE"
}
trap cleanup EXIT
git worktree add --quiet --detach "$CHECKOUT" "$COMMIT"
[ ! -d .tools ] || ln -s "$REPO/.tools" "$CHECKOUT/.tools"
echo "Running the tests on $SHORT (${RELEASE_TEST:-tests/run.sh --all})"
(cd "$CHECKOUT" && bash -c "${RELEASE_TEST:-tests/run.sh --all}") || die "the tests failed on $NAME ($SHORT): no zip built"

# Stage the files from git, so nothing the tests left behind ships
mkdir "$STAGE/$MOD_ID"
PATHS=()
while read -r p; do
    git cat-file -e "$COMMIT:$p" 2>/dev/null && PATHS+=("$p")
done < <(git show "$COMMIT:deploy.include" | sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d')
git archive --format=tar "$COMMIT" -- "${PATHS[@]}" | tar -xf - -C "$STAGE/$MOD_ID"
for f in "${RELEASE_FILES[@]}"; do
    git show "$COMMIT:$f" > "$STAGE/$MOD_ID/$(basename "$f")"
done

mkdir -p dist
ZIP="dist/$MOD_ID-$VERSION.zip"
CHECKLIST="dist/$MOD_ID-$VERSION-checklist.md"
rm -f "$ZIP"
(cd "$STAGE" && python3 -m zipfile -c "$REPO/$ZIP" "$MOD_ID")
(cd "$CHECKOUT" && python3 tools/test_plan_docs.py --checklist "$REPO/$CHECKLIST")

echo -e "${GREEN}Built $ZIP${NC}"
echo "  checklist: $CHECKLIST"
[ -n "$TAG" ] || echo "  (from origin/main, untagged: tag $VERSION_TAG on $SHORT and build the tag to publish it)"
