"""Unit tests for tools/capture_metrics.py (debuglog.txt summary lines to CSV)."""
import csv
import io
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

import capture_metrics as metrics
from helpers import write

LINE = ("[=ERROR=] 1234.56 [apirateslife] capture metrics: v=1 | mode=operation | outcome=abandoned"
        " | target=Riot Squad Kestrel | id=ABC-123 | macro=ship_pir_s_fighter_01_a_macro | size=S"
        " | type=shiptype.fighter | owner=scaleplate | checks=2 | chances=24/48 | gates= | total=63\n")


class ParseLine(unittest.TestCase):
    def test_reads_the_fields_after_the_marker(self):
        fields = metrics.parse_line(LINE)
        self.assertEqual(fields["mode"], "operation")
        self.assertEqual(fields["target"], "Riot Squad Kestrel")
        self.assertEqual(fields["chances"], "24/48")
        self.assertEqual(fields["total"], "63")

    def test_an_empty_value_stays_empty(self):
        self.assertEqual(metrics.parse_line(LINE)["gates"], "")

    def test_enum_values_keep_their_last_part(self):
        self.assertEqual(metrics.parse_line(LINE)["type"], "fighter")
        self.assertEqual(metrics.parse_line(LINE.replace("shiptype.fighter", "fighter"))["type"], "fighter")

    def test_other_lines_are_not_summaries(self):
        self.assertIsNone(metrics.parse_line("[apirateslife] capture: ended on X (ABC-123): abandoned\n"))
        self.assertIsNone(metrics.parse_line(""))

    def test_a_value_may_contain_an_equals_sign(self):
        self.assertEqual(metrics.parse_line(LINE.replace("Riot Squad Kestrel", "A=B"))["target"], "A=B")


class ReadLogsAndWrite(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_one_row_per_summary_with_its_source_and_line(self):
        log = write(self.tmp.name, "debuglog.txt", "noise\n" + LINE + "more noise\n" + LINE)
        rows = metrics.read_logs([log])
        self.assertEqual([(r["source"], r["line"]) for r in rows], [(log, 2), (log, 4)])

    def test_folders_are_searched_for_txt_files(self):
        write(self.tmp.name, "a/debuglog.txt", LINE)
        write(self.tmp.name, "b/c/debuglog.txt", LINE)
        write(self.tmp.name, "b/save.xml", LINE)
        self.assertEqual(len(metrics.read_logs([self.tmp.name])), 2)

    def test_known_fields_come_first_in_order_then_unknown_ones_sorted(self):
        rows = [metrics.parse_line(LINE.replace("total=63", "total=63 | zeta=1 | alpha=2"))]
        cols = metrics.columns(rows)
        self.assertEqual(cols[:4], ["source", "line", "v", "mode"])
        self.assertEqual(cols[-2:], ["alpha", "zeta"])

    def test_the_csv_has_a_header_and_blank_missing_fields(self):
        out = io.StringIO()
        metrics.write_csv([{"source": "x", "line": 1, **metrics.parse_line(LINE)}], out)
        rows = list(csv.DictReader(io.StringIO(out.getvalue())))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["target"], "Riot Squad Kestrel")
        self.assertEqual(rows[0]["morale"], "")

    def test_main_writes_the_output_file(self):
        log = write(self.tmp.name, "debuglog.txt", LINE)
        out = os.path.join(self.tmp.name, "out.csv")
        with redirect_stderr(io.StringIO()):
            self.assertEqual(metrics.main([log, "-o", out]), 0)
        with open(out, encoding="utf-8") as f:
            self.assertEqual(len(list(csv.DictReader(f))), 1)

    def test_main_fails_on_a_missing_path(self):
        err = io.StringIO()
        with redirect_stderr(err), redirect_stdout(io.StringIO()):
            self.assertEqual(metrics.main([os.path.join(self.tmp.name, "nope.txt")]), 1)
        self.assertIn("not found", err.getvalue())


if __name__ == "__main__":
    unittest.main()
