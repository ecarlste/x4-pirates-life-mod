#!/usr/bin/env python3
"""Writes the manual release checklist: every @manual scenario in the game-test plan
(tests/game/features/*.feature), grouped by feature, as Markdown checkboxes with their steps.

@manual scenarios are the ones checked by hand at every release instead of by a game test (see
tools/check-test-plan.py). make release will write this next to the release zip, and a CI
release job's approval gate can show it.

Usage: tools/manual-checklist.py [-o <file>] [features dir]
"""
import importlib.util
import os
import sys


def load_checker():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "check-test-plan.py")
    spec = importlib.util.spec_from_file_location("check_test_plan", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def checklist(scenarios):
    manual = [s for s in scenarios if "manual" in s["tags"]]
    lines = [
        "# Manual release checklist",
        "",
        "Check each of these by hand in game before a release. They're the `@manual` scenarios in "
        "`tests/game/features/`; everything else is covered by the game tests or is `@pending`.",
        "",
    ]
    if not manual:
        lines.append("No manual scenarios.")
        return "\n".join(lines) + "\n"
    current = None
    for scenario in manual:
        if scenario["file"] != current:
            current = scenario["file"]
            lines += [f"## {scenario['feature']} (`{current}`)", ""]
        lines.append(f"- [ ] **{scenario['title']}**")
        for step in scenario["steps"]:
            lines.append(f"  - {step}" if not step.startswith("|") else f"    {step}")
        lines.append("")
    return "\n".join(lines)


def main(argv):
    out = None
    if len(argv) >= 2 and argv[0] == "-o":
        out, argv = argv[1], argv[2:]
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    features_dir = argv[0] if argv else os.path.join(root, "tests", "game", "features")

    scenarios, problems = load_checker().read_features(features_dir)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        print("Fix the test plan first (tools/check-test-plan.py)", file=sys.stderr)
        return 1
    text = checklist(scenarios)
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        count = sum("manual" in s["tags"] for s in scenarios)
        print(f"Wrote {count} manual scenarios to {out}")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
