#!/usr/bin/env python3
"""Checks the game-test plan (tests/game/features/*.feature) against the game tests.

The feature files describe, in Gherkin (Given/When/Then), what the mod should do. Every scenario
carries a tag: the name of the game test that covers it (the name the test reports, e.g.
@pilot_bail_intact), @pending when nothing covers it yet but a game test should, or @manual when
it's checked by hand at every release instead (tools/manual-checklist.py lists those). This
script fails when:
  - a feature file isn't valid enough Gherkin to read (unknown step keyword, scenario without a tag)
  - a scenario's tag names no game test
  - a game test has no scenario
  - a spec (docs/specs/*.md) doesn't link a feature file that exists
Game test names are the $name values the tests report in the harness
(tests/game/apirateslife_tests/md/apirateslife_tests.xml).

Usage: tools/check-test-plan.py [features dir] [harness file] [specs dir]
"""
import glob
import os
import re
import sys

STEP_KEYWORDS = ("Given ", "When ", "Then ", "And ", "But ", "* ")
SCENARIO = re.compile(r"^(Scenario|Scenario Outline|Example):\s*(.+)$")
FEATURE_LINK = re.compile(r"tests/game/features/([A-Za-z0-9_-]+\.feature)")
NOT_SPECS = ("README.md", "_template.md")


def read_features(features_dir):
    """Returns (scenarios, problems): scenarios as dicts with file, feature (its title), line,
    title, tags (without the @) and steps (the step and Examples lines, stripped)."""
    scenarios, problems = [], []
    files = sorted(glob.glob(os.path.join(features_dir, "*.feature")))
    if not files:
        problems.append(f"no .feature files in {features_dir}")
    for path in files:
        name = os.path.basename(path)
        tags, in_scenario, seen_feature, in_examples, feature_title = [], False, False, False, name
        with open(path, encoding="utf-8") as f:
            for number, raw in enumerate(f, 1):
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                where = f"{name}:{number}"
                if line.startswith("@"):
                    tags += line.split()
                    continue
                if line.startswith("Feature:"):
                    seen_feature = True
                    feature_title = line[len("Feature:"):].strip() or name
                    continue
                match = SCENARIO.match(line)
                if match:
                    if not seen_feature:
                        problems.append(f"{where}: scenario before the Feature: line")
                    if not tags:
                        problems.append(f"{where}: scenario has no tag (a game test name, @pending or @manual)")
                    scenarios.append({"file": name, "feature": feature_title, "line": number,
                                      "title": match.group(2), "tags": [t[1:] for t in tags], "steps": []})
                    tags, in_scenario, in_examples = [], True, False
                    continue
                if line.startswith("Examples:"):
                    in_examples = True
                    if scenarios:
                        scenarios[-1]["steps"].append(line)
                    continue
                if line.startswith("|"):
                    if not in_examples:
                        problems.append(f"{where}: table row outside Examples")
                    elif scenarios:
                        scenarios[-1]["steps"].append(line)
                    continue
                if in_scenario:
                    if not line.startswith(STEP_KEYWORDS):
                        problems.append(f"{where}: step must start with Given, When, Then, And or But: {line}")
                    else:
                        scenarios[-1]["steps"].append(line)
                    in_examples = False
                # Anything else before the first scenario is the feature's description
    return scenarios, problems


def check_specs(specs_dir, features_dir):
    """Every spec links at least one feature file, and the files it links exist."""
    problems = []
    for path in sorted(glob.glob(os.path.join(specs_dir, "*.md"))):
        name = os.path.basename(path)
        if name in NOT_SPECS:
            continue
        with open(path, encoding="utf-8") as f:
            links = set(FEATURE_LINK.findall(f.read()))
        if not links:
            problems.append(f"spec {name} links no feature file (add a Scenarios: line under Done when)")
        for link in sorted(links):
            if not os.path.isfile(os.path.join(features_dir, link)):
                problems.append(f"spec {name} links tests/game/features/{link}, which doesn't exist")
    return problems


def game_test_names(harness):
    with open(harness, encoding="utf-8") as f:
        return set(re.findall(r"\$name = '([a-z0-9_]+)'", f.read()))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    features_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests", "game", "features")
    harness = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        root, "tests", "game", "apirateslife_tests", "md", "apirateslife_tests.xml")
    specs_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.join(root, "docs", "specs")

    scenarios, problems = read_features(features_dir)
    tests = game_test_names(harness)
    covered, pending, manual = set(), 0, 0
    for scenario in scenarios:
        name, number, title = scenario["file"], scenario["line"], scenario["title"]
        if "pending" in scenario["tags"] and "manual" in scenario["tags"]:
            problems.append(f"{name}:{number}: @pending and @manual contradict each other (scenario: {title})")
        for tag in scenario["tags"]:
            if tag == "pending":
                pending += 1
            elif tag == "manual":
                manual += 1
            elif tag in tests:
                covered.add(tag)
            else:
                problems.append(f"{name}:{number}: @{tag} is not a game test (scenario: {title})")
    for test in sorted(tests - covered):
        problems.append(f"game test {test} has no scenario in the test plan")
    problems += check_specs(specs_dir, features_dir)

    if problems:
        print("\n".join(problems))
        return 1
    print(f"{len(scenarios)} scenarios ({pending} pending, {manual} manual) cover all {len(tests)} game tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
