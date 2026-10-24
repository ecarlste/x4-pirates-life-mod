"""Unit tests for tools/check_test_plan_changes.py (the PR check), without git."""
import unittest

import check_test_plan_changes as changes

SPEC_A = "Scenarios: [a](../../tests/game/features/a.feature)"


def reader(texts):
    """A read() for find_problems: the given texts by path; a missing path is a deleted file."""
    return lambda path: texts.get(path)


class FindProblems(unittest.TestCase):
    def test_a_spec_changed_with_its_feature_file_is_fine(self):
        changed = {"docs/specs/a.md", "tests/game/features/a.feature"}
        self.assertEqual(changes.find_problems(changed, reader({"docs/specs/a.md": SPEC_A})), [])

    def test_a_spec_changed_without_its_feature_file(self):
        changed = {"docs/specs/a.md", "tests/game/features/b.feature"}
        self.assertEqual(changes.find_problems(changed, reader({"docs/specs/a.md": SPEC_A})),
                         ["docs/specs/a.md changed, but tests/game/features/a.feature didn't"])

    def test_a_spec_without_a_link_says_its_feature_file(self):
        self.assertEqual(changes.find_problems({"docs/specs/x.md"}, reader({"docs/specs/x.md": "no link"})),
                         ["docs/specs/x.md changed, but its feature file didn't"])

    def test_deleted_specs_readme_template_and_other_files_are_ignored(self):
        changed = {"docs/specs/deleted.md", "docs/specs/README.md", "docs/specs/_template.md",
                   "docs/specs/flow.svg", "docs/research/note.md"}
        self.assertEqual(changes.find_problems(changed, reader({"docs/specs/README.md": "x", "docs/specs/_template.md": "x"})), [])

    def test_game_tests_need_some_feature_file_to_change(self):
        game = "tests/game/apirateslife_tests/md/apirateslife_tests.xml"
        self.assertEqual(changes.find_problems({game}, reader({})),
                         ["the game tests (tests/game/apirateslife_tests/) changed, but no feature file in tests/game/features/ did"])
        self.assertEqual(changes.find_problems({game, "tests/game/features/z.feature"}, reader({})), [])

    def test_the_opt_out_phrase_is_found_however_its_written(self):
        for body in ("Test plan: no change", "test plan:no change", "## Test plan\n\nTEST PLAN:   No Change."):
            self.assertIsNotNone(changes.NO_CHANGE.search(body), body)
        self.assertIsNone(changes.NO_CHANGE.search("Test plan: changed"))


if __name__ == "__main__":
    unittest.main()
