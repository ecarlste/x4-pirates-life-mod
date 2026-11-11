"""Unit tests for tools/select_tests.py: reading the paths-filter globs and picking suites."""
import os
import subprocess
import unittest

import select_tests as st

FILTERS = st.compile_filters({
    "everything": ["tests/run.sh"],
    "none": ["docs/**", "README.md"],
    "shellcheck": ["**/*.sh", "**/*.bats"],
    "lua": ["ui/**/*.lua"],
    "typescript": ["tools/**/*.ts"],
    "doc-paths": ["docs/**/*.md", "tools/check-doc-paths.ts"],
    "tests/deploy.bats": ["deploy.sh", "tests/deploy.bats"],
    "tests/python/test_texts.py": ["t/**"],
    "tests/Deploy.Tests.ps1": ["deploy.ps1", "deploy.sh"],
})


class GlobRegex(unittest.TestCase):
    def test_select_star_stays_within_a_folder(self):
        self.assertTrue(st.glob_regex("md/*.xml").match("md/a.xml"))
        self.assertFalse(st.glob_regex("md/*.xml").match("md/sub/a.xml"))
        self.assertFalse(st.glob_regex("*.md").match("docs/a.md"))

    def test_select_double_star_crosses_folders_including_none(self):
        self.assertTrue(st.glob_regex("docs/**").match("docs/specs/a.md"))
        self.assertTrue(st.glob_regex("**/*.sh").match("deploy.sh"))
        self.assertTrue(st.glob_regex("**/*.sh").match("tests/lua/run.sh"))
        self.assertTrue(st.glob_regex("ui/**/*.lua").match("ui/a.lua"))

    def test_select_other_characters_are_literal(self):
        self.assertTrue(st.glob_regex("tests/Deploy.Tests.ps1").match("tests/Deploy.Tests.ps1"))
        self.assertFalse(st.glob_regex("tests/Deploy.Tests.ps1").match("tests/DeployxTests.ps1"))
        self.assertFalse(st.glob_regex("deploy.sh").match("deploy.sh.bak"))


class Pick(unittest.TestCase):
    def test_select_a_script_picks_every_suite_that_lists_it(self):
        picked, reason = st.pick(FILTERS, ["deploy.sh"])
        self.assertIsNone(reason)
        self.assertEqual(set(picked), {"shellcheck", "tests/deploy.bats", "tests/Deploy.Tests.ps1"})

    def test_select_docs_pick_nothing(self):
        self.assertEqual(st.pick(FILTERS, ["README.md"]), ({"none": ["README.md"]}, None))

    def test_select_an_everything_file_picks_everything(self):
        self.assertEqual(st.pick(FILTERS, ["deploy.sh", "tests/run.sh"]), ({}, "tests/run.sh changed"))

    def test_select_suites_skip_everything_none_and_game_keys(self):
        filters = dict(FILTERS, **{"game:booty": []})
        self.assertEqual(st.suites(filters), ["shellcheck", "lua", "typescript", "doc-paths", "tests/deploy.bats", "tests/python/test_texts.py", "tests/Deploy.Tests.ps1"])


class GithubOutputs(unittest.TestCase):
    def test_select_outputs_say_which_jobs_run(self):
        self.assertEqual(st.github_outputs(["tests/Deploy.Tests.ps1", "lua", "none"], FILTERS), [
            "suites=lua tests/Deploy.Tests.ps1", "bash=false", "shellcheck=false", "lua=true",
            "typescript=false", "doc-paths=false", "pester=tests/Deploy.Tests.ps1"])

    def test_select_typescript_runs_its_own_job_not_bats(self):
        # The bats job's run.sh has no node_modules, so typescript stays out of its suites
        self.assertEqual(st.github_outputs(["typescript", "tests/deploy.bats"], FILTERS), [
            "suites=tests/deploy.bats", "bash=true", "shellcheck=false", "lua=false", "typescript=true",
            "doc-paths=false", "pester="])
        self.assertEqual(st.github_outputs(["typescript"], FILTERS), [
            "suites=", "bash=false", "shellcheck=false", "lua=false", "typescript=true", "doc-paths=false", "pester="])

    def test_select_doc_paths_runs_its_own_job_not_bats(self):
        # It needs Node 22.18 or later, which the bats job doesn't set up
        self.assertEqual(st.github_outputs(["doc-paths", "none"], FILTERS), [
            "suites=", "bash=false", "shellcheck=false", "lua=false", "typescript=false", "doc-paths=true", "pester="])

    def test_select_nothing_matched_runs_no_job(self):
        self.assertEqual(st.github_outputs(["none"], FILTERS),
                         ["suites=", "bash=false", "shellcheck=false", "lua=false", "typescript=false", "doc-paths=false",
                          "pester="])

    def test_select_everything_runs_every_job(self):
        outputs = st.github_outputs(["everything"], FILTERS)
        self.assertIn("bash=true", outputs)
        self.assertIn("lua=true", outputs)
        self.assertIn("typescript=true", outputs)
        self.assertIn("doc-paths=true", outputs)
        self.assertNotIn("typescript", outputs[0])
        self.assertNotIn("doc-paths", outputs[0])
        self.assertIn("pester=tests/Deploy.Tests.ps1", outputs)


class Check(unittest.TestCase):
    def test_select_a_suite_run_on_every_change_does_not_cover_files(self):
        filters = dict(FILTERS, **st.compile_filters({"doc-paths": ["**"]}))
        self.assertEqual(st.uncovered(filters, ["deploy.sh", "README.md", "new/tool.rb"]), ["new/tool.rb"])

    def test_select_a_suite_run_on_every_change_is_picked_by_any_file(self):
        filters = dict(FILTERS, **st.compile_filters({"doc-paths": ["**"]}))
        picked, _ = st.pick(filters, ["README.md"])
        self.assertEqual(set(picked), {"none", "doc-paths"})


class RealFilters(unittest.TestCase):
    def test_select_every_tracked_file_and_suite_has_a_filter(self):
        repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        result = subprocess.run(["python3", os.path.join(repo, "tools", "select_tests.py"), "--check"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
