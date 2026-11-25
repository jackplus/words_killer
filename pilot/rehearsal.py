#!/usr/bin/env python3
"""Run a complete local pilot rehearsal with synthetic participants and recordings."""

import argparse
import json
import random
import shutil
import subprocess
import sys
from collections import Counter
from datetime import date, datetime, time, timedelta
from pathlib import Path
from tempfile import TemporaryDirectory

sys.dont_write_bytecode = True
import prepare
from merge import merge_participants, write_table


PILOT_DIRECTORY = Path(__file__).resolve().parent
SEED = "words-killer-rehearsal-v1"


def run_rehearsal(day, directory):
    day1 = day + timedelta(days=1)
    cutoff = datetime.combine(day1, time(10), tzinfo=prepare.TAIPEI)
    training_start = datetime.combine(day, time(14), tzinfo=prepare.TAIPEI)
    book = prepare.read_book(prepare.CORE_BOOK)
    groups = prepare.candidate_groups(book, None, day, cutoff)
    allocations = Counter()

    for slot in range(1, 13):
        args = argparse.Namespace(slot=slot, cohort_seed=SEED, day=day, rehearsal=True)
        rng = random.Random(f"{SEED}:words:{slot}")
        packet = prepare.make_packet(book, prepare.match_sets(groups, rng), args, rng)
        participant = packet["participant_id"]
        participant_directory = directory / participant
        participant_directory.mkdir()
        packet_path = participant_directory / "participant.json"
        assignment_path = participant_directory / "assignment.csv"
        prepare.write_packet(packet, packet_path, assignment_path)
        allocations[prepare.allocation(SEED, slot)] += 1
        rounds, probes = [], []
        outcomes = {}
        for index, block in enumerate(packet["rounds"]):
            started = training_start + timedelta(minutes=14 * index)
            completed = slot != 12
            summary = (started + timedelta(minutes=10)).isoformat() if completed else ""
            state = "completed" if completed else "abandoned"
            rounds.append((participant, block["round_id"], started.isoformat(), summary, state))
            correct_words = 5 if block["arm"] == "B" else 4
            outcomes.update((item["id"], int(index < correct_words)) for index, item in enumerate(block["items"]))

        for index, word_id in enumerate(packet["probe_order"]):
            submitted = cutoff + timedelta(seconds=index + 1)
            probes.append((participant, word_id, submitted.isoformat(), outcomes[word_id], "valid"))

        write_table(participant_directory, "rounds.csv", rounds)
        write_table(participant_directory, "probes.csv", probes)

    if len(allocations) != 4 or set(allocations.values()) != {3}:
        raise ValueError("彩排分派未达到每种组合 3 人")
    shutil.copyfile(directory / "P01/participant.json", directory / "participant.json")
    merge_participants(directory, directory, rehearsal=True)

    analysis = subprocess.run(
        [sys.executable, str(PILOT_DIRECTORY.parent / "scripts/vocabulary-pilot.py"), str(directory), "--through", day1.isoformat()],
        capture_output=True, text=True, check=True,
    )
    result = json.loads(analysis.stdout)
    if result["decision"] != "advance" or result["paired_participants_who_started_both_rounds"] != 12:
        raise ValueError("统计脚本未得出预期的合成判定")
    if any(result["paired_by_order"][order]["participants"] != 6 for order in ("AB", "BA")):
        raise ValueError("实际统计的 AB、BA 人数应各为 6 人")
    if abs(result["paired_lift_pp"] - 100 / 6) > 1e-9:
        raise ValueError("合成判定的人均正确率提升应为 16.67 个百分点")
    for arm, expected_correct in (("A", 48), ("B", 60)):
        stats = result["arms"][arm]
        expected = ((stats["short_practice_completion"], 11, 12), (stats["next_day_accuracy"], expected_correct, 72))
        if any((metric["numerator"], metric["denominator"]) != (count, total) for metric, count, total in expected):
            raise ValueError(f"{arm} 组的彩排分子或分母不符")
    result["rehearsal"] = True
    (directory / "decision.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--day", type=date.fromisoformat, required=True, help="Synthetic D0 date")
    parser.add_argument("--output", type=Path, required=True, help="New output directory")
    args = parser.parse_args()
    try:
        if args.output.exists() or args.output.is_symlink():
            parser.error("输出目录已存在，请指定新目录。")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix=".pilot-rehearsal-", dir=args.output.parent) as working:
            directory = Path(working) / "output"
            directory.mkdir()
            run_rehearsal(args.day, directory)
            if args.output.exists() or args.output.is_symlink():
                parser.error("输出目录已存在，请指定新目录。")
            directory.rename(args.output)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        parser.exit(2, f"{detail}\n")
    print(f"合成彩排通过：{args.output / 'decision.json'}")


if __name__ == "__main__":
    main()
