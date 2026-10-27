#!/usr/bin/env python3
"""Turns the capture metrics summary lines in X4 debuglog.txt files into one CSV.

md/apirateslife_metrics.xml logs one line per capture attempt when it ends:
  [apirateslife] capture metrics: v=1 | mode=operation | outcome=abandoned | ... | total=63
key=value fields split by " | " (docs/specs/capture-metrics.md). Each line becomes a CSV row: the
source file and line number, the known fields in a fixed order, then any fields this script
doesn't know yet (sorted by name), so a newer mod's logs still convert. Enum values keep only their
last part (shiptype.fighter becomes fighter).

Usage: tools/capture_metrics.py [-o out.csv] <debuglog.txt or folder> ...
A folder is searched for *.txt files, subfolders included. Without -o the CSV goes to stdout.
"""
import argparse
import csv
import glob
import os
import re
import sys

MARKER = "[apirateslife] capture metrics: "
FIELDS = ["v", "mode", "outcome", "target", "id", "macro", "size", "type", "owner", "value",
          "crew", "crewcap", "pilotskill", "crewskill", "morale", "wing", "attackers", "playerhits",
          "started", "gates", "firstcheck", "checks", "chances", "successes", "crewbailed",
          "pilotbailed", "total"]
ENUM_FIELDS = ("type",)
ENUM = re.compile(r"^[a-z_]+\.([A-Za-z0-9_]+)$")


def parse_line(line):
    """The fields of one summary line as a dict, or None if the line isn't one."""
    at = line.find(MARKER)
    if at < 0:
        return None
    fields = {}
    for part in line[at + len(MARKER):].rstrip("\r\n").split(" | "):
        key, sep, value = part.partition("=")
        key = key.strip()
        if not sep or not key:
            continue
        value = value.strip()
        if key in ENUM_FIELDS:
            match = ENUM.match(value)
            if match:
                value = match.group(1)
        fields[key] = value
    return fields


def read_logs(paths):
    """Rows (dicts with source, line and the fields) from every summary line in the given files
    and folders, in order."""
    files = []
    for path in paths:
        if os.path.isdir(path):
            files += sorted(glob.glob(os.path.join(path, "**", "*.txt"), recursive=True))
        else:
            files.append(path)
    rows = []
    for name in files:
        with open(name, encoding="utf-8", errors="replace") as f:
            for number, line in enumerate(f, 1):
                fields = parse_line(line)
                if fields is not None:
                    rows.append({"source": name, "line": number, **fields})
    return rows


def columns(rows):
    """source, line, the known fields, then the unknown ones sorted"""
    extra = sorted({key for row in rows for key in row} - set(FIELDS) - {"source", "line"})
    return ["source", "line"] + FIELDS + extra


def write_csv(rows, out):
    writer = csv.DictWriter(out, fieldnames=columns(rows), restval="", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)


def main(argv):
    parser = argparse.ArgumentParser(description="Turn capture metrics lines in debuglog.txt files into a CSV.")
    parser.add_argument("paths", nargs="+", help="debuglog.txt files or folders of them")
    parser.add_argument("-o", "--output", help="CSV file to write (default: stdout)")
    args = parser.parse_args(argv)
    missing = [p for p in args.paths if not os.path.exists(p)]
    if missing:
        print("not found: " + ", ".join(missing), file=sys.stderr)
        return 1
    rows = read_logs(args.paths)
    if args.output:
        with open(args.output, "w", encoding="utf-8", newline="") as out:
            write_csv(rows, out)
    else:
        write_csv(rows, sys.stdout)
    print(f"{len(rows)} capture(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
