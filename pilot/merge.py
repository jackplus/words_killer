#!/usr/bin/env python3
"""Combine one final anonymous CSV snapshot per participant."""

import argparse
import csv
import json
import re
from pathlib import Path


TEMPLATES = Path(__file__).resolve().parent / "templates"
TABLES = ("assignment.csv", "rounds.csv", "probes.csv")


def headers_for(name):
    with (TEMPLATES / name).open(encoding="utf-8-sig", newline="") as source:
        return next(csv.reader(source))


def write_table(directory, name, rows):
    with (directory / name).open("x", encoding="utf-8", newline="") as destination:
        writer = csv.writer(destination)
        writer.writerow(headers_for(name))
        writer.writerows(rows)


def merge_participants(source, destination, rehearsal=False):
    participants = sorted(path for path in source.glob("P[0-9][0-9]") if path.is_dir())
    if not participants:
        raise ValueError("找不到 P01…P12 参与者目录。")
    if any((destination / name).exists() for name in TABLES):
        raise ValueError("目标目录已有 CSV，请使用新目录。")

    tables = {name: [] for name in TABLES}
    for participant in participants:
        if not re.fullmatch(r"P(0[1-9]|1[0-2])", participant.name):
            raise ValueError(f"{participant.name} 不是有效的匿名编号。")
        packet = json.loads((participant / "participant.json").read_text(encoding="utf-8-sig"))
        if (not isinstance(packet, dict) or packet.get("participant_id") != participant.name
                or packet.get("rehearsal") is not rehearsal):
            raise ValueError(f"{participant.name} 的题包编号不符，或混用了真人和模拟资料。")
        for name in TABLES:
            with (participant / name).open(encoding="utf-8-sig", newline="") as file:
                reader = csv.reader(file)
                expected = headers_for(name)
                if next(reader, None) != expected:
                    raise ValueError(f"{participant.name}/{name} 的表头与模板不同。")
                for row in reader:
                    if len(row) != len(expected) or row[0] != participant.name:
                        raise ValueError(f"{participant.name}/{name} 的字段数或匿名编号不同。")
                    tables[name].append(row)

    destination.mkdir(parents=True, exist_ok=True)
    for name, rows in tables.items():
        write_table(destination, name, rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        merge_participants(args.source, args.destination)
    except (OSError, TypeError, ValueError) as error:
        parser.exit(2, f"{error}\n")
    print(f"已汇总：{args.destination}")


if __name__ == "__main__":
    main()
