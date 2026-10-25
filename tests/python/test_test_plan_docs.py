"""Unit tests for tools/test_plan_docs.py."""
import io
import os
import tempfile
import textwrap
import unittest
from contextlib import redirect_stdout

from helpers import write

import test_plan_docs as docs
import check_test_plan as plan

FEATURE = textwrap.dedent("""\
    # Spec: docs/specs/things.md
    Feature: Things
      Things work, and are described
      over two lines.

      @alpha_works
      Scenario: Alpha works
        Given a thing
        Then alpha works

      @test_beta_rules
      Scenario: Beta rules
        Then beta rules

      @manual
      Scenario: Gamma looks right
        Then it looks right

      @pending
      Scenario: Delta, test planned
        Given <n> things
        Examples:
          | n |
    """)
GAME, UNIT = {"alpha_works"}, {"test_beta_rules"}


def scenario(tags, title="S"):
    return {"file": "things.feature", "line": 1, "title": title, "tags": tags, "steps": ["Then it works"]}


class Fixture(unittest.TestCase):
    """A temporary folder with one feature file, a harness, unit tests and an output folder."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.features = os.path.join(self.root, "features")
        self.feature = write(self.features, "things.feature", FEATURE)
        self.harness = write(self.root, "tests.xml", "table[$name = 'alpha_works']")
        self.units = os.path.join(self.root, "lua")
        write(self.units, "test_things.lua", "function TestThings:test_beta_rules()\nend\n")
        self.out = os.path.join(self.root, "out")

    def tearDown(self):
        self.tmp.cleanup()

    def run_main(self, *args):
        output = io.StringIO()
        with redirect_stdout(output):
            code = docs.main(["--features", self.features, "--harness", self.harness, "--units", self.units,
                              "--out", self.out, *args])
        return code, output.getvalue()


class FeatureInfo(Fixture):
    def test_reads_title_description_and_spec(self):
        self.assertEqual(docs.feature_info(self.feature),
                         ("Things", ["Things work, and are described", "over two lines."], "docs/specs/things.md"))

    def test_falls_back_to_the_file_name_without_a_feature_line_or_spec(self):
        path = write(self.features, "bare.feature", "@t\nScenario: S\n")
        self.assertEqual(docs.feature_info(path), ("bare.feature", [], None))


class Labels(unittest.TestCase):
    def test_automated_names_each_test_and_its_level(self):
        self.assertEqual(docs.label(scenario(["alpha_works"]), "game", GAME, UNIT), "**Automated:** in game `alpha_works`")
        self.assertEqual(docs.label(scenario(["test_beta_rules"]), "unit", GAME, UNIT),
                         "**Automated:** unit test `test_beta_rules`")
        self.assertEqual(docs.label(scenario(["test_beta_rules", "alpha_works"]), "game", GAME, UNIT),
                         "**Automated:** unit test `test_beta_rules`; in game `alpha_works`")

    def test_several_unit_tests_say_tests(self):
        both = {"test_a", "test_b"}
        self.assertEqual(docs.label(scenario(["test_a", "test_b"]), "unit", set(), both),
                         "**Automated:** unit tests `test_a`, `test_b`")

    def test_manual_and_pending_get_checkboxes(self):
        self.assertTrue(docs.label(scenario(["manual"]), "manual", GAME, UNIT).startswith("- [ ] **Manual:**"))
        self.assertTrue(docs.label(scenario(["pending"]), "pending", GAME, UNIT).startswith("- [ ] **Pending:**"))

    def test_counts_row_ends_with_by_hand_in_bold(self):
        self.assertEqual(docs.counts_row({"unit": 1, "game": 2, "manual": 3, "pending": 4}), "1 | 2 | 3 | 4 | **7**")


class Pages(Fixture):
    def scenarios(self):
        scenarios, problems = plan.read_features(self.features)
        self.assertEqual(problems, [])
        return scenarios

    def test_feature_page_has_header_links_counts_and_every_scenario(self):
        content, title, counts = docs.feature_page(self.feature, self.scenarios(), GAME, UNIT, plan.classify,
                                                   os.path.join(docs.ROOT, "docs", "test-plan"))
        self.assertEqual(title, "Things")
        self.assertEqual(counts, {"unit": 1, "game": 1, "manual": 1, "pending": 1})
        lines = content.splitlines()
        self.assertIn("Don't edit", lines[0])
        self.assertIn("# Things", lines)
        self.assertIn("Things work, and are described over two lines.", lines)
        self.assertIn("Source: [`tests/game/features/things.feature`](../../tests/game/features/things.feature) "
                      "· Spec: [`docs/specs/things.md`](../specs/things.md)", lines)
        self.assertIn("| 1 | 1 | 1 | 1 | **2** |", lines)
        for heading in ("### Alpha works", "### Beta rules", "### Gamma looks right", "### Delta, test planned"):
            self.assertIn(heading, lines)
        self.assertIn("  Given <n> things", lines)
        self.assertIn("    | n |", lines)

    def test_index_lists_each_feature_and_the_totals(self):
        counts = {"unit": 1, "game": 1, "manual": 1, "pending": 1}
        index = docs.index_page([("things.md", "Things", counts)], counts).splitlines()
        self.assertIn("| [Things](things.md) | 4 | 1 | 1 | 1 | 1 | **2** |", index)
        self.assertIn("| **Total** | 4 | 1 | 1 | 1 | 1 | **2** |", index)

    def test_generate_returns_a_page_per_feature_and_the_index(self):
        pages, problems = docs.generate(self.features, self.harness, self.units, self.out)
        self.assertEqual(problems, [])
        self.assertEqual(sorted(pages), ["README.md", "things.md"])

    def test_generate_refuses_a_plan_the_checker_cant_read(self):
        write(self.features, "broken.feature", "Feature: B\n  Scenario: No tag\n")
        pages, problems = docs.generate(self.features, self.harness, self.units, self.out)
        self.assertEqual(pages, {})
        self.assertTrue(any("scenario has no tag" in p for p in problems))


class ReleaseChecklist(Fixture):
    def checklist(self):
        scenarios, _ = plan.read_features(self.features)
        return docs.release_checklist(self.features, scenarios, GAME, UNIT, plan.classify)

    def test_lists_only_manual_and_pending_with_steps(self):
        text = self.checklist()
        self.assertIn("**2 to check** (1 manual, 1 pending)", text)
        self.assertIn("## Things (`things.feature`)", text)
        self.assertIn("- [ ] **Gamma looks right** (manual)", text)
        self.assertIn("- [ ] **Delta, test planned** (pending: automated test planned)", text)
        self.assertIn("    Given <n> things", text)
        self.assertIn("      | n |", text)
        self.assertNotIn("Alpha works", text)
        self.assertNotIn("Beta rules", text)

    def test_says_when_nothing_is_left_to_check(self):
        write(self.features, "things.feature", "Feature: Things\n  @alpha_works\n  Scenario: Alpha works\n    Then ok\n")
        self.assertIn("Nothing to check by hand", self.checklist())


class Main(Fixture):
    def test_writes_pages_then_check_passes(self):
        code, output = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("Updated 2 of 2 test-plan pages", output)
        self.assertEqual(self.run_main("--check")[0], 0)

    def test_check_names_stale_and_orphaned_pages_and_writing_fixes_them(self):
        self.run_main()
        write(self.out, "things.md", "edited by hand\n")
        write(self.out, "gone.md", "old\n")
        code, output = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("out of date: docs/test-plan/things.md", output)
        self.assertIn("no feature file any more: docs/test-plan/gone.md", output)
        self.run_main()
        self.assertFalse(os.path.exists(os.path.join(self.out, "gone.md")))
        self.assertEqual(self.run_main("--check")[0], 0)

    def test_checklist_writes_a_file_and_leaves_the_pages_alone(self):
        target = os.path.join(self.root, "dist", "release-checklist.md")
        code, output = self.run_main("--checklist", target)
        self.assertEqual(code, 0)
        self.assertIn("Wrote 2 scenarios to check by hand", output)
        self.assertTrue(os.path.isfile(target))
        self.assertFalse(os.path.exists(self.out))


if __name__ == "__main__":
    unittest.main()
