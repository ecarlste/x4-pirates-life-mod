#!/usr/bin/env bats
# Every XML file that ships to the game, or into the test extension, must be well-formed by a
# strict parser. X4 uses libxml2, which rejects things lenient parsers accept (e.g. "--" inside a
# comment), and then silently skips the whole file.

setup() {
    command -v python3 >/dev/null || skip "python3 is not installed"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "all mod XML files are well-formed" {
    cd "$REPO_ROOT"
    run python3 - <<'PY'
import glob, sys, xml.dom.minidom
files = ["content.xml"] + [f for d in ("md", "aiscripts", "libraries", "t", "tests/game")
                           for f in glob.glob(d + "/**/*.xml", recursive=True)]
bad = []
for f in files:
    try:
        xml.dom.minidom.parse(f)
    except Exception as e:
        bad.append(f"{f}: {e}")
print("\n".join(bad) or f"{len(files)} files OK")
sys.exit(1 if bad else 0)
PY
    echo "$output"
    [ "$status" -eq 0 ]
}
