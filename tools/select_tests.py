#!/usr/bin/env python3
"""Picks the test suites, or the game tests, a change needs, from .github/test-filters.json.

The filters file is dorny/paths-filter's format, which CI reads with that action: each key names
a suite (a test file, or "shellcheck", "lua", "variants") and lists the path globs it depends on;
"everything" lists files that need every suite, "none" files that need no test. This script reads
the same file for make test, so CI and local runs pick alike.

The change is everything since the branch left the base ref (git diff BASE...HEAD), plus
uncommitted and untracked files. Prints the picked suites, one per line, and on stderr why.

With --game, picks game tests by the "game:" keys instead: game:<feature> runs the game tests that
tests/game/features/<feature>.feature tags; game:everything runs them all; game:load runs the
first test of the run, enough to see the mod loads without errors; game:harness (the game tests
file) runs the features whose feature files changed too, or every test when none did. Prints the
names the tests report, in run order; nothing means no game test is needed.

Usage: tools/select_tests.py [--base REF] [--all] [--game]   pick for this branch (default base origin/main)
       tools/select_tests.py --keys JSON --github    CI: turn paths-filter's matched keys into step outputs
       tools/select_tests.py --check                 every tracked file and every suite has a filter
If git can't compare with the base, every suite is picked.
"""
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from check_test_plan import read_features

FILTERS = ".github/test-filters.json"
EVERYTHING, NONE = "everything", "none"
PSEUDO_SUITES = ("shellcheck", "lua", "variants")
GAME_TESTS = "tests/game/apirateslife_tests/md/apirateslife_tests.xml"
FEATURES = "tests/game/features"
REPORTED_NAME = re.compile(r"\$name = '([A-Za-z0-9_]+)'")
# Test files that must each have a filter, so they run at all
SUITE_FILES = re.compile(r"^tests/([^/]+\.bats|[^/]+\.Tests\.ps1|python/test_[^/]+\.py)$")


def glob_regex(pattern):
    """A glob as paths-filter (picomatch) reads it: * stays within a folder, ** crosses folders."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def compile_filters(raw):
    return {key: [glob_regex(p) for p in patterns] for key, patterns in raw.items()}


def load_filters():
    with open(FILTERS, encoding="utf-8") as f:
        return compile_filters(json.load(f))


def suites(filters):
    """Every suite, in the order the filters file lists them."""
    return [key for key in filters if key not in (EVERYTHING, NONE) and not key.startswith("game:")]


def matching_keys(filters, path):
    return [key for key, patterns in filters.items() if any(p.match(path) for p in patterns)]


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.split("\n")


def changed_files(base):
    """Paths changed since HEAD left base, including uncommitted and untracked ones."""
    files = git("diff", "--name-only", "--no-renames", f"{base}...HEAD")
    files += git("diff", "--name-only", "--no-renames", "HEAD")
    files += git("ls-files", "--others", "--exclude-standard")
    return sorted({f for f in files if f})


def pick(filters, paths):
    """({key: [paths that matched it]}, everything_reason or None)."""
    picked = {}
    for path in paths:
        for key in matching_keys(filters, path):
            if key == EVERYTHING:
                return {}, f"{path} changed"
            picked.setdefault(key, []).append(path)
    return picked, None


def game_tests():
    """Every game test's reported name, in the order the run plays them (Run's $Tests)."""
    cues = {el.get("name"): REPORTED_NAME.search(ET.tostring(el, encoding="unicode"))
            for el in ET.parse(GAME_TESTS).getroot().find("cues")}
    order = re.findall(r"[A-Za-z0-9_]+", ET.parse(GAME_TESTS).getroot().find(".//set_value[@name='$Tests']").get("exact"))
    return [cues[cue].group(1) for cue in order if cues.get(cue)]


def feature_tests(feature, run_order):
    """The game tests a feature file tags (its other tags are unit tests, @pending, @manual)."""
    scenarios, _ = read_features(FEATURES)
    tags = {tag for sc in scenarios if os.path.basename(sc["file"]) == f"{feature}.feature" for tag in sc["tags"]}
    return [test for test in run_order if test in tags]


def pick_game(filters, paths):
    """({game test: [paths that need it]}, everything_reason or None, run order)."""
    run_order = game_tests()
    picked, harness = {}, None
    for path in paths:
        for key in matching_keys(filters, path):
            if not key.startswith("game:"):
                continue
            if key == "game:everything":
                return {}, f"{path} changed", run_order
            if key == "game:harness":
                harness = path
                continue
            tests = run_order[:1] if key == "game:load" else feature_tests(key[5:], run_order)
            for test in tests:
                if path not in picked.setdefault(test, []):
                    picked[test].append(path)
    changed_features = any(p.startswith(FEATURES + "/") for p in paths)
    if harness and not changed_features:
        return {}, f"{harness} changed, but no feature file did", run_order
    return picked, None, run_order


def main_game(filters, base, everything):
    picked, reason, run_order = {}, "--all" if everything else None, []
    try:
        run_order = game_tests()
        if not everything:
            picked, reason, run_order = pick_game(filters, changed_files(base))
    except (subprocess.CalledProcessError, OSError):
        reason = f"can't compare with {base}"
    if reason:
        print(f"Running every game test: {reason}", file=sys.stderr)
        chosen = run_order
    else:
        chosen = [test for test in run_order if test in picked]
        for test in chosen:
            why = picked[test]
            more = f" and {len(why) - 1} more" if len(why) > 1 else ""
            print(f"{test}: {why[0]}{more} changed", file=sys.stderr)
        if not chosen:
            print("No game tests needed for these changes", file=sys.stderr)
    if chosen:
        print("\n".join(chosen))
    return 0


def check(filters):
    problems = [f"{path} matches no filter in {FILTERS}" for path in git("ls-files")
                if path and not matching_keys(filters, path)]
    problems += [f"{path} has no filter of its own in {FILTERS}" for path in git("ls-files")
                 if SUITE_FILES.match(path) and path not in filters]
    problems += [f"{key} names a test file that doesn't exist" for key in suites(filters)
                 if key not in PSEUDO_SUITES and not os.path.isfile(key)]
    problems += [f"{key} names no feature file" for key in filters if key.startswith("game:")
                 and key not in ("game:everything", "game:harness", "game:load")
                 and not os.path.isfile(f"{FEATURES}/{key[5:]}.feature")]
    problems += [f"{path} has no game: filter of its own in {FILTERS}" for path in git("ls-files")
                 if path.startswith(FEATURES + "/") and f"game:{os.path.basename(path)[:-8]}" not in filters]
    print("\n".join(problems) or f"{FILTERS}: OK")
    return 1 if problems else 0


def github_outputs(keys, filters):
    """Step outputs for the CI jobs: which jobs run, and the Pester files to give run.ps1."""
    picked = suites(filters) if EVERYTHING in keys else [k for k in suites(filters) if k in keys]
    pester = [k for k in picked if k.endswith(".Tests.ps1")]
    bash = [k for k in picked if not k.endswith(".Tests.ps1") and k != "lua"]
    return [
        f"suites={' '.join(picked)}",
        f"bash={'true' if bash else 'false'}",
        f"shellcheck={'true' if 'shellcheck' in picked else 'false'}",
        f"lua={'true' if 'lua' in picked else 'false'}",
        f"pester={','.join(pester)}",
    ]


def main(argv):
    base, everything, keys, mode = "origin/main", False, None, "pick"
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--base" and args:
            base = args.pop(0)
        elif arg == "--keys" and args:
            keys = json.loads(args.pop(0) or "[]")
        elif arg == "--game":
            mode = "game"
        elif arg in ("--all", "--github", "--check"):
            everything = everything or arg == "--all"
            mode = arg[2:] if arg != "--all" else mode
        else:
            print(__doc__.strip(), file=sys.stderr)
            return 2

    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    filters = load_filters()
    if mode == "check":
        return check(filters)
    if mode == "game":
        return main_game(filters, base, everything)
    if mode == "github":
        print("\n".join(github_outputs([EVERYTHING] if everything else keys or [], filters)))
        return 0

    picked, reason = {}, "--all" if everything else None
    if not everything:
        try:
            picked, reason = pick(filters, changed_files(base))
        except (subprocess.CalledProcessError, OSError):
            reason = f"can't compare with {base}"
    if reason:
        print(f"Running every suite: {reason}", file=sys.stderr)
        chosen = suites(filters)
    else:
        chosen = [key for key in suites(filters) if key in picked]
        for key in chosen:
            why = picked[key]
            more = f" and {len(why) - 1} more" if len(why) > 1 else ""
            print(f"{key}: {why[0]}{more} changed", file=sys.stderr)
        if not chosen:
            print("No tests needed for these changes", file=sys.stderr)
    if chosen:
        print("\n".join(chosen))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
