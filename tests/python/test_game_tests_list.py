"""Checks the $Tests list in the game-test harness (tests/game/apirateslife_tests/md/apirateslife_tests.xml):
one test per line, so parallel branches that each add a test don't conflict on one long line, and
the list matches the root test cues, so a test someone forgot to list doesn't silently never run.
The $ReleaseOnly list (the tests only the release tier runs) is laid out the same way, or empty as
"[]", and names only tests in $Tests."""
import os
import re
import unittest
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HARNESS = os.path.join(REPO, "tests", "game", "apirateslife_tests", "md", "apirateslife_tests.xml")

# Read from the raw text: an XML parser turns the newlines in an attribute into spaces
LIST = r'<set_value name="\$%s" exact="([^"]*)"'
ENTRY = re.compile(r"^\s*([A-Za-z_]\w*)(,?)\s*$")


def list_problems(value, list_name="Tests"):
    """Returns (names, problems) for a list expression ($Tests by default): "[" alone on its line,
    then one name per line, each but the last followed by a comma, then "]" on its own line.
    names is None when the list isn't laid out that way at all."""
    lines = value.split("\n")
    if len(lines) < 3 or lines[0].strip() != "[" or lines[-1].strip() != "]":
        return None, ['$%s must open with "[" and close with "]", each on its own line, with one test per line between' % list_name]
    names, problems = [], []
    entries = lines[1:-1]
    for number, line in enumerate(entries, start=1):
        match = ENTRY.match(line)
        if not match:
            problems.append("$%s line %d is not one test name: %r" % (list_name, number + 1, line.strip()))
            continue
        name, comma = match.groups()
        last = number == len(entries)
        if comma and last:
            problems.append("$%s: %s is last, so it takes no comma" % (list_name, name))
        elif not comma and not last:
            problems.append("$%s: %s needs a comma after it" % (list_name, name))
        if name in names:
            problems.append("$%s lists %s twice" % (list_name, name))
        names.append(name)
    return names, problems


def root_test_cues(root):
    """The root cues that are tests: they fire on a bare event_cue_signalled and signal Report."""
    cues = []
    for cue in root.findall("./cues/cue"):
        fires = any("cue" not in e.attrib for e in cue.findall("./conditions/event_cue_signalled"))
        reports = any(e.get("cue") == "Report" for e in cue.iter() if e.tag.startswith("signal_cue"))
        if fires and reports:
            cues.append(cue.get("name"))
    return cues


def release_only_problems(text, tests):
    """Every problem with the $ReleaseOnly list: its format (or "[]" when empty), and names not in
    $Tests (tests, or None when $Tests itself couldn't be read)."""
    found = re.findall(LIST % "ReleaseOnly", text)
    if len(found) != 1:
        return ["expected one $ReleaseOnly list, found %d" % len(found)]
    if found[0].strip() == "[]":
        return []
    names, problems = list_problems(found[0], "ReleaseOnly")
    if names is None or tests is None:
        return problems
    return problems + ["$ReleaseOnly lists %s, which isn't in $Tests" % n for n in names if n not in tests]


def harness_problems(text):
    """Every problem with the lists in the harness text: $Tests's format, listed names with no
    root cue, and root test cues it doesn't list; then $ReleaseOnly's."""
    found = re.findall(LIST % "Tests", text)
    if len(found) != 1:
        return ["expected one $Tests list, found %d" % len(found)]
    names, problems = list_problems(found[0])
    if names is not None:
        root = ET.fromstring(text)
        roots = {cue.get("name") for cue in root.findall("./cues/cue")}
        problems += ["$Tests lists %s, but there's no root cue by that name" % n for n in names if n not in roots]
        problems += ["%s is a test cue missing from $Tests, so it never runs" % n for n in root_test_cues(root) if n not in names]
    return problems + release_only_problems(text, names)


def make_harness(tests_value, cues, release_only="[]"):
    """A minimal harness: Run with the given $Tests and $ReleaseOnly values (no $ReleaseOnly for
    None), plus the given root cues' XML."""
    release = '' if release_only is None else '<set_value name="$ReleaseOnly" exact="%s"/>' % release_only
    return """<mdscript name="T"><cues>
  <cue name="Run">
    <conditions><event_cue_signalled cue="md.Setup.GameStart"/></conditions>
    <actions><set_value name="$Tests" exact="%s"/>%s</actions>
    <cues><cue name="Report" instantiate="true"><conditions><event_cue_signalled/></conditions></cue></cues>
  </cue>
  %s
</cues></mdscript>""" % (tests_value, release, cues)


def make_test_cue(name):
    return """<cue name="%s">
    <conditions><event_cue_signalled/></conditions>
    <cues><cue name="%s_Timeout"><delay exact="1s"/>
      <actions><signal_cue_instantly cue="Report" param="table[]"/></actions></cue></cues>
  </cue>""" % (name, name)


class GameTestsList(unittest.TestCase):
    def test_game_tests_list_matches_test_cues(self):
        with open(HARNESS, encoding="utf-8") as f:
            self.assertEqual(harness_problems(f.read()), [])

    def test_game_tests_list_accepts_one_per_line(self):
        text = make_harness("[\n  A,\n  B\n]", make_test_cue("A") + make_test_cue("B"))
        self.assertEqual(harness_problems(text), [])

    def test_game_tests_list_flags_unlisted_test_cue(self):
        text = make_harness("[\n  A\n]", make_test_cue("A") + make_test_cue("B"))
        self.assertEqual(harness_problems(text), ["B is a test cue missing from $Tests, so it never runs"])

    def test_game_tests_list_flags_name_with_no_cue(self):
        text = make_harness("[\n  A,\n  Gone\n]", make_test_cue("A"))
        self.assertEqual(harness_problems(text), ["$Tests lists Gone, but there's no root cue by that name"])

    def test_game_tests_list_flags_two_names_on_one_line(self):
        text = make_harness("[\n  A, B\n]", make_test_cue("A") + make_test_cue("B"))
        self.assertIn("$Tests line 2 is not one test name: 'A, B'", harness_problems(text))

    def test_game_tests_list_flags_single_line(self):
        text = make_harness("[A, B]", make_test_cue("A") + make_test_cue("B"))
        problems = harness_problems(text)
        self.assertEqual(len(problems), 1)
        self.assertIn("each on its own line", problems[0])

    def test_game_tests_list_flags_commas_and_duplicates(self):
        _, problems = list_problems("[\n  A\n  B,\n  A,\n]")
        self.assertEqual(problems, [
            "$Tests: A needs a comma after it",
            "$Tests: A is last, so it takes no comma",
            "$Tests lists A twice",
        ])

    def test_release_only_accepts_empty_or_listed_tests(self):
        cues = make_test_cue("A") + make_test_cue("B")
        self.assertEqual(harness_problems(make_harness("[\n  A,\n  B\n]", cues, "[]")), [])
        self.assertEqual(harness_problems(make_harness("[\n  A,\n  B\n]", cues, "[\n  B\n]")), [])

    def test_release_only_flags_a_test_not_in_tests(self):
        text = make_harness("[\n  A\n]", make_test_cue("A") + make_test_cue("B"), "[\n  A,\n  Gone\n]")
        self.assertIn("$ReleaseOnly lists Gone, which isn't in $Tests", harness_problems(text))

    def test_release_only_flags_layout_and_a_missing_list(self):
        text = make_harness("[\n  A,\n  B\n]", make_test_cue("A") + make_test_cue("B"), "[A, B]")
        self.assertEqual(len(harness_problems(text)), 1)
        self.assertIn("$ReleaseOnly must open", harness_problems(text)[0])
        self.assertEqual(harness_problems(make_harness("[\n  A\n]", make_test_cue("A"), None)),
                         ["expected one $ReleaseOnly list, found 0"])

    def test_game_tests_list_ignores_cues_that_are_not_tests(self):
        helper = '<cue name="Helper"><conditions><event_cue_signalled/></conditions></cue>'
        text = make_harness("[\n  A\n]", make_test_cue("A") + helper)
        self.assertEqual(harness_problems(text), [])


if __name__ == "__main__":
    unittest.main()
