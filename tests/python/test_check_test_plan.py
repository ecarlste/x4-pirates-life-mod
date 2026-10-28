"""Unit tests for tools/check_test_plan.py."""
import os
import tempfile
import textwrap
import unittest

from helpers import write

import check_test_plan as plan

FEATURE = textwrap.dedent("""\
    # Spec: docs/specs/a.md
    Feature: Alpha
      A description.

      @alpha_works
      Scenario: Alpha works
        Given a thing
        When it happens
        Then alpha works

      @test_beta_rules @beta_works
      Scenario Outline: Beta for <n>
        Given <n> things
        Then beta works

        Examples:
          | n |
          | 1 |
    """)


class ReadFeatures(unittest.TestCase):
    def read(self, text, name="a.feature"):
        with tempfile.TemporaryDirectory() as folder:
            write(folder, name, text)
            return plan.read_features(folder)

    def test_reads_each_scenario_with_its_feature_tags_and_steps(self):
        scenarios, problems = self.read(FEATURE)
        self.assertEqual(problems, [])
        self.assertEqual([s["title"] for s in scenarios], ["Alpha works", "Beta for <n>"])
        first, second = scenarios
        self.assertEqual(first["feature"], "Alpha")
        self.assertEqual(first["file"], "a.feature")
        self.assertEqual(first["line"], 6)
        self.assertEqual(first["tags"], ["alpha_works"])
        self.assertEqual(first["steps"], ["Given a thing", "When it happens", "Then alpha works"])
        self.assertEqual(second["tags"], ["test_beta_rules", "beta_works"])
        self.assertEqual(second["steps"], ["Given <n> things", "Then beta works", "Examples:", "| n |", "| 1 |"])

    def test_tags_can_span_several_lines(self):
        scenarios, _ = self.read("Feature: A\n  @one\n  @two\n  Scenario: S\n    Given x\n")
        self.assertEqual(scenarios[0]["tags"], ["one", "two"])

    def test_reports_a_scenario_without_a_tag(self):
        _, problems = self.read("Feature: A\n  Scenario: Untagged\n    Given x\n")
        self.assertEqual(problems, ["a.feature:2: scenario has no tag (a game test name, @pending or @manual)"])

    def test_reports_a_step_without_a_gherkin_keyword(self):
        _, problems = self.read("Feature: A\n  @t\n  Scenario: S\n    Givn x\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("a.feature:4: step must start with Given", problems[0])

    def test_reports_a_scenario_before_the_feature_line_and_a_stray_table_row(self):
        _, problems = self.read("@t\nScenario: Early\n  Given x\n  | a |\n")
        self.assertIn("a.feature:2: scenario before the Feature: line", problems)
        self.assertIn("a.feature:4: table row outside Examples", problems)

    def test_reports_a_folder_without_feature_files(self):
        with tempfile.TemporaryDirectory() as folder:
            scenarios, problems = plan.read_features(folder)
        self.assertEqual(scenarios, [])
        self.assertEqual(problems, [f"no .feature files in {folder}"])


class TestNames(unittest.TestCase):
    def test_game_test_names_are_the_names_the_harness_reports(self):
        with tempfile.TemporaryDirectory() as folder:
            harness = write(folder, "tests.xml", "table[$name = 'alpha_works', $ok = true] table[$name = 'beta_works']")
            self.assertEqual(plan.game_test_names(harness), {"alpha_works", "beta_works"})

    def test_unit_test_names_are_the_test_methods_of_test_classes(self):
        with tempfile.TemporaryDirectory() as folder:
            write(folder, "test_a.lua", "TestA = {}\nfunction TestA:test_one()\nend\nfunction TestA.test_two()\nend\n"
                                         "local function helper()\nend\nfunction TestA:notATest()\nend\n")
            write(folder, "other.lua", "function TestB:test_ignored()\nend\n")
            names, problems = plan.unit_test_names(folder)
        self.assertEqual(names, {"test_one", "test_two"})
        self.assertEqual(problems, [])

    def test_unit_test_names_include_the_python_tests_beside_the_lua_ones(self):
        with tempfile.TemporaryDirectory() as folder:
            write(folder, "lua/test_a.lua", "function TestA:test_lua()\nend\n")
            write(folder, "python/test_tool.py", "class T(unittest.TestCase):\n    def test_python(self):\n        pass\n"
                                                  "    def helper(self):\n        pass\n")
            write(folder, "python/helpers.py", "    def test_not_a_test_file(self):\n")
            names, problems = plan.unit_test_names(os.path.join(folder, "lua"))
        self.assertEqual(names, {"test_lua", "test_python"})
        self.assertEqual(problems, [])

    def test_unit_test_names_must_be_unique_across_lua_and_python(self):
        with tempfile.TemporaryDirectory() as folder:
            write(folder, "lua/test_a.lua", "function TestA:test_same()\nend\n")
            write(folder, "python/test_b.py", "    def test_same(self):\n")
            _, problems = plan.unit_test_names(os.path.join(folder, "lua"))
        self.assertEqual(problems, ["unit test test_same is defined twice (test_a.lua, test_b.py); names must be unique"])

    def test_unit_test_names_must_be_unique(self):
        with tempfile.TemporaryDirectory() as folder:
            write(folder, "test_a.lua", "function TestA:test_same()\nend\n")
            write(folder, "test_b.lua", "function TestB:test_same()\nend\n")
            _, problems = plan.unit_test_names(folder)
        self.assertEqual(problems, ["unit test test_same is defined twice (test_a.lua, test_b.lua); names must be unique"])


class Classify(unittest.TestCase):
    GAME, UNIT = {"alpha_works"}, {"test_beta"}

    def test_levels(self):
        cases = {
            ("pending",): "pending",
            ("manual",): "manual",
            ("test_beta",): "unit",
            ("alpha_works",): "game",
            ("test_beta", "alpha_works"): "game",
        }
        for tags, level in cases.items():
            self.assertEqual(plan.classify(list(tags), self.GAME, self.UNIT), level, tags)


def scenario(tags, title="S", line=1):
    return {"file": "a.feature", "line": line, "title": title, "tags": tags, "steps": [], "feature": "A"}


class CheckTags(unittest.TestCase):
    GAME, UNIT = {"alpha_works", "beta_works"}, {"test_gamma"}

    def test_counts_pending_manual_and_unit_coverage(self):
        problems, counts = plan.check_tags(
            [scenario(["alpha_works"]), scenario(["beta_works"]), scenario(["pending"]),
             scenario(["manual"]), scenario(["test_gamma"])], self.GAME, self.UNIT)
        self.assertEqual(problems, [])
        self.assertEqual(counts, {"pending": 1, "manual": 1, "unit": 1})

    def test_unknown_tags_and_uncovered_game_tests(self):
        problems, _ = plan.check_tags([scenario(["alpha_works"]), scenario(["typo"], "Typo", 7)], self.GAME, self.UNIT)
        self.assertEqual(problems, [
            "a.feature:7: @typo is not a game test or unit test (scenario: Typo)",
            "game test beta_works has no scenario in the test plan",
        ])

    def test_tests_pending_and_manual_dont_mix(self):
        for tags in (["pending", "manual"], ["alpha_works", "manual"], ["test_gamma", "pending"]):
            problems, _ = plan.check_tags([scenario(tags, "Mixed", 3), scenario(["alpha_works", "beta_works"])],
                                          self.GAME, self.UNIT)
            self.assertEqual(problems, ["a.feature:3: tests, @pending and @manual can't be mixed (scenario: Mixed)"], tags)


class CheckSpecs(unittest.TestCase):
    def test_every_spec_links_an_existing_feature_file(self):
        with tempfile.TemporaryDirectory() as root:
            features = os.path.join(root, "features")
            specs = os.path.join(root, "specs")
            write(features, "a.feature", "Feature: A\n")
            write(specs, "good.md", "Scenarios: tests/game/features/a.feature")
            write(specs, "none.md", "No link")
            write(specs, "broken.md", "tests/game/features/missing.feature")
            write(specs, "README.md", "No link, but not a spec")
            write(specs, "_template.md", "No link, but not a spec")
            problems = plan.check_specs(specs, features)
        self.assertEqual(problems, [
            "spec broken.md links tests/game/features/missing.feature, which doesn't exist",
            "spec none.md links no feature file (add a Scenarios: line under Done when)",
        ])


if __name__ == "__main__":
    unittest.main()
