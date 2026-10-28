"""Checks on the mod's own texts in t/0001-l044.xml."""
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class Texts(unittest.TestCase):
    def test_texts_have_no_unescaped_parentheses(self):
        # X4 drops anything in parentheses from a text (vanilla uses it for translator comments),
        # so "(%s)" vanishes and the arguments after it shift; write \( and \) to show them
        with open(os.path.join(REPO, "t", "0001-l044.xml"), encoding="utf-8") as f:
            texts = re.findall(r'<t id="(\d+)">([^<]*)</t>', f.read())
        bad = [i for i, t in texts if re.search(r"(?<!\\)\(", t)]
        self.assertEqual(bad, [], "texts with unescaped parentheses: %s" % bad)


if __name__ == "__main__":
    unittest.main()
