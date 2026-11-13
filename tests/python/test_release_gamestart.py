"""Checks the release tests' gamestart (tests/game/apirateslife_release_tests/libraries/gamestarts.xml)
against the game tests' (tests/game/apirateslife_tests/libraries/gamestarts.xml): the same start,
so the harness's tests run on a release save as on a new test game, apart from its id, name and
description and the "nosave" tag, which would stop the release sessions saving."""
import os
import unittest
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME_TESTS = os.path.join(REPO, "tests", "game", "apirateslife_tests", "libraries", "gamestarts.xml")
RELEASE_TESTS = os.path.join(REPO, "tests", "game", "apirateslife_release_tests", "libraries", "gamestarts.xml")
OWN = ("id", "name", "description", "tags")


def gamestart(path):
    starts = ET.parse(path).getroot().findall("./add/gamestart")
    assert len(starts) == 1, f"{path} should add one gamestart"
    return starts[0]


def without_own(start):
    """The gamestart as text, without the attributes each one sets for itself."""
    start = ET.fromstring(ET.tostring(start))
    for name in OWN:
        start.attrib.pop(name, None)
    return ET.tostring(start, encoding="unicode")


class ReleaseGamestartTest(unittest.TestCase):
    def test_it_is_the_game_tests_start_apart_from_its_own_attributes(self):
        self.assertEqual(without_own(gamestart(RELEASE_TESTS)), without_own(gamestart(GAME_TESTS)))

    def test_it_can_be_saved(self):
        release = gamestart(RELEASE_TESTS)
        self.assertEqual(release.get("id"), "apirateslife_release_test")
        self.assertNotIn("nosave", release.get("tags", "").split())


if __name__ == "__main__":
    unittest.main()
