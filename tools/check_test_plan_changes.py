#!/usr/bin/env python3
"""PR check: when a spec or a game test changes, the game-test plan should change with it.

Compares the current commit with a base ref (the PR's target branch) and fails when:
  - a spec (docs/specs/*.md) changed but none of the feature files it links did
  - the game tests (tests/game/apirateslife_tests/) changed but no feature file did
unless the PR description says "Test plan: no change" (for typo fixes and the like). The
description comes from the PR_BODY environment variable.

Usage: PR_BODY="..." tools/check_test_plan_changes.py <base ref>
"""
import os
import re
import subprocess
import sys

SPECS = "docs/specs/"
NOT_SPECS = ("docs/specs/README.md", "docs/specs/_template.md")
FEATURES = "tests/game/features/"
GAME_TESTS = "tests/game/apirateslife_tests/"
FEATURE_LINK = re.compile(r"tests/game/features/([A-Za-z0-9_-]+\.feature)")
NO_CHANGE = re.compile(r"test plan:\s*no change", re.IGNORECASE)


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def read_text(path):
    """A file's text, or None when it no longer exists (deleted in the PR)."""
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return f.read()


def find_problems(changed, read):
    """What the changed paths need but lack: a changed spec needs one of the feature files it links
    to change too, and changed game tests need some feature file to change. read(path) gives a
    spec's text, or None if it was deleted."""
    features_changed = {path for path in changed if path.startswith(FEATURES)}
    problems = []
    for path in sorted(changed):
        if path.startswith(SPECS) and path.endswith(".md") and path not in NOT_SPECS:
            text = read(path)
            if text is None:
                continue  # deleted spec
            links = {FEATURES + link for link in FEATURE_LINK.findall(text)}
            if not links & features_changed:
                linked = ", ".join(sorted(links)) or "its feature file"
                problems.append(f"{path} changed, but {linked} didn't")
    if any(path.startswith(GAME_TESTS) for path in changed) and not features_changed:
        problems.append(f"the game tests ({GAME_TESTS}) changed, but no feature file in {FEATURES} did")
    return problems


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip())
        return 2
    base = sys.argv[1]
    changed = set(git("diff", "--name-only", f"{base}...HEAD").split())
    problems = find_problems(changed, read_text)
    if not problems:
        print("Test plan: OK")
        return 0
    if NO_CHANGE.search(os.environ.get("PR_BODY", "")):
        print("Test plan: no change (as the PR description says), despite:")
        print("\n".join(f"  {problem}" for problem in problems))
        return 0
    print("\n".join(problems))
    print("Update the scenarios in tests/game/features/ (see docs/PROJECT.md, Workflow), or say "
          "'Test plan: no change' in the PR description if the behaviour didn't change.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
