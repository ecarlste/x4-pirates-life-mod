#!/usr/bin/env python3
"""Checks the test plan (tests/game/features/*.feature) against the game tests and unit tests.

The feature files describe, in Gherkin (Given/When/Then), what the mod should do. Every scenario
carries tags saying how it's verified (docs/PROJECT.md, "Test plan"):
  - the tests that cover it: game tests by the name they report (e.g. @pilot_bail_intact), unit
    tests by their test function's name (e.g. @test_refuses_default_in_any_case); or
  - @pending: no test yet, one is planned; checked by hand until then; or
  - @manual: checked by hand for now, as automating it is hard; automation is still wanted.
This script fails when:
  - a feature file isn't valid enough Gherkin to read (unknown step keyword, scenario without a tag)
  - a scenario's tag names no test, or mixes tests, @pending and @manual
  - a game test has no scenario (unit tests may test details no scenario names)
  - two unit tests share a name
  - a spec (docs/specs/*.md) doesn't link a feature file that exists
Game test names are the $name values the tests report in the harness
(tests/game/apirateslife_tests/md/apirateslife_tests.xml); unit tests are the test_* methods of
the Test* classes in tests/lua/test_*.lua.

Usage: tools/check_test_plan.py [features dir] [harness file] [specs dir] [unit tests dir]
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


UNIT_TEST = re.compile(r"^function\s+Test\w*[:.](test_\w+)\s*\(", re.MULTILINE)


def unit_test_names(unit_dir):
    """Returns (names, problems): every LuaUnit test method name in tests/lua/test_*.lua."""
    names, problems = {}, []
    for path in sorted(glob.glob(os.path.join(unit_dir, "test_*.lua"))):
        with open(path, encoding="utf-8") as f:
            for name in UNIT_TEST.findall(f.read()):
                where = os.path.basename(path)
                if name in names:
                    problems.append(f"unit test {name} is defined twice ({names[name]}, {where}); names must be unique")
                names[name] = where
    return set(names), problems


def classify(tags, game_tests, unit_tests):
    """How a scenario is verified: "unit", "game" (its lowest automated level), "manual" or "pending"."""
    if "pending" in tags:
        return "pending"
    if "manual" in tags:
        return "manual"
    if any(t in unit_tests for t in tags) and not any(t in game_tests for t in tags):
        return "unit"
    return "game"


def check_tags(scenarios, game_tests, unit_tests):
    """Returns (problems, counts): every tag must name a test or be @pending/@manual, the three
    kinds don't mix, and every game test needs a scenario. counts has "pending" and "manual" (tags)
    and "unit" (scenarios covered only by unit tests)."""
    problems, covered = [], set()
    counts = {"pending": 0, "manual": 0, "unit": 0}
    for scenario in scenarios:
        name, number, title = scenario["file"], scenario["line"], scenario["title"]
        kinds = {"pending" if t == "pending" else "manual" if t == "manual" else "test" for t in scenario["tags"]}
        if len(kinds) > 1:
            problems.append(f"{name}:{number}: tests, @pending and @manual can't be mixed (scenario: {title})")
        for tag in scenario["tags"]:
            if tag in ("pending", "manual"):
                counts[tag] += 1
            elif tag in game_tests:
                covered.add(tag)
            elif tag not in unit_tests:
                problems.append(f"{name}:{number}: @{tag} is not a game test or unit test (scenario: {title})")
        if classify(scenario["tags"], game_tests, unit_tests) == "unit":
            counts["unit"] += 1
    for test in sorted(game_tests - covered):
        problems.append(f"game test {test} has no scenario in the test plan")
    return problems, counts


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    features_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "tests", "game", "features")
    harness = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        root, "tests", "game", "apirateslife_tests", "md", "apirateslife_tests.xml")
    specs_dir = sys.argv[3] if len(sys.argv) > 3 else os.path.join(root, "docs", "specs")
    unit_dir = sys.argv[4] if len(sys.argv) > 4 else os.path.join(root, "tests", "lua")

    scenarios, problems = read_features(features_dir)
    tests = game_test_names(harness)
    units, unit_problems = unit_test_names(unit_dir)
    tag_problems, counts = check_tags(scenarios, tests, units)
    problems += unit_problems + tag_problems
    problems += check_specs(specs_dir, features_dir)

    if problems:
        print("\n".join(problems))
        return 1
    print(f"{len(scenarios)} scenarios ({counts['pending']} pending, {counts['manual']} manual) cover all "
          f"{len(tests)} game tests; {counts['unit']} covered by unit tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
