#!/usr/bin/env python3
"""Prepare one anonymous Words Killer trial packet and its frozen assignment."""

import argparse
import base64
import csv
import json
import random
import re
import subprocess
import wave
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from difflib import SequenceMatcher
from itertools import combinations
from pathlib import Path
from tempfile import TemporaryDirectory
from zoneinfo import ZoneInfo


TAIPEI = ZoneInfo("Asia/Taipei")
CORE_BOOK = Path(__file__).resolve().parents[1] / "Words killer/Resources/word_bank.json"
ASSIGNMENT_FIELDS = ("participant_id", "round_id", "arm", "order", "word_id", "frozen_due_at")


def timestamp(value):
    parsed = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    if parsed.utcoffset() is None:
        raise ValueError("备份时间必须带 UTC 偏移")
    return parsed.astimezone(TAIPEI)


def equivalent(left, right):
    meaning = lambda word: set(re.split(r"[；;，,、]", word["meaning_key"]))
    left_term, right_term = left["term_key"], right["term_key"]
    near_forms = (
        min(len(left_term), len(right_term)) >= 4
        and SequenceMatcher(None, left_term, right_term).ratio() >= 0.88
    )
    return (
        left_term == right_term
        or bool(meaning(left) & meaning(right))
        or bool(left["pronunciation"] and left["pronunciation"] == right["pronunciation"])
        or near_forms
    )


def read_book(path):
    book = {}
    rows = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(rows, list):
        raise ValueError("词书 JSON 应为内置词条数组")
    for row in rows:
        if not isinstance(row, dict) or row.get("language") != "english":
            continue
        if not all(isinstance(row.get(key), str) and row[key].strip() for key in ("id", "difficulty", "term", "translation")):
            continue
        if row["id"] in book:
            raise ValueError(f"重复词条 ID：{row['id']}")
        word = {key: row[key].strip() for key in ("id", "difficulty", "term", "translation")}
        word["pronunciation"] = (row.get("pronunciation") or "").strip().casefold()
        word["term_key"] = word["term"].casefold()
        word["meaning_key"] = re.sub(r"\s+", "", word["translation"].casefold())
        book[word["id"]] = word
    return book


def candidate_groups(book, backup, day0, cutoff):
    groups = defaultdict(list)
    if backup is None:
        for word in book.values():
            groups[word["difficulty"], "known"].append((cutoff, word))
        return groups

    payload = json.loads(backup.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict) or not isinstance(payload.get("progressRecords"), list):
        raise ValueError("备份 JSON 应包含 progressRecords 数组")
    exported_at = timestamp(payload["exportedAt"]) if payload.get("exportedAt") else None
    if exported_at and exported_at.date() != day0:
        raise ValueError("请使用 D0 当天作答前导出的本地备份")
    seen = set()
    for row in payload["progressRecords"]:
        word_id = row.get("wordID")
        if word_id not in book or row.get("languageRawValue") != "english" or not row.get("lastReviewedAt"):
            continue
        due = timestamp(row["nextReviewDate"])
        reviewed = timestamp(row["lastReviewedAt"])
        rating = row.get("lastRatingRawValue")
        if reviewed.date() > day0 or (exported_at and reviewed > exported_at):
            continue
        if due.date() != cutoff.date() or due > cutoff or rating not in ("known", "unknown", "fuzzy"):
            continue
        if word_id in seen:
            raise ValueError(f"备份进度出现重复词条 ID：{word_id}")
        seen.add(word_id)
        groups[book[word_id]["difficulty"], rating].append((due, book[word_id]))
    return groups


def match_sets(groups, rng):
    pairs = [
        (abs(left[0] - right[0]), rng.random(), left, right)
        for group in groups.values()
        for left, right in combinations(group, 2)
        if not equivalent(left[1], right[1])
    ]
    selected = []
    sets = [[], []]
    for _, _, left, right in sorted(pairs, key=lambda pair: pair[:2]):
        if any(equivalent(word, saved) for _, word in (left, right) for saved in selected):
            continue
        pair = [left, right]
        rng.shuffle(pair)
        for word_set, item in zip(sets, pair):
            word_set.append(item)
            selected.append(item[1])
        if len(sets[0]) == 6:
            positions = shuffled(range(6), rng)
            return [[word_set[index] for index in positions] for word_set in sets]
    raise ValueError("无法配齐 6 对同难度、同上次评分且不重复的次日到期词。请核对词书与测评截止时间，词量不足请延后入组。")


def allocation(seed, slot):
    block, offset = divmod(slot - 1, 4)
    cells = [(order, set_for_a) for order in ("AB", "BA") for set_for_a in (0, 1)]
    random.Random(f"{seed}:allocation:{block}").shuffle(cells)
    return cells[offset]


def choose_distractors(pool, target, field, number, rng, previously_used=()):
    candidates = list(pool)
    rng.shuffle(candidates)
    candidates.sort(key=lambda candidate: (
        candidate[field] in previously_used,
        candidate["difficulty"] != target["difficulty"],
    ))
    chosen = []
    for word in candidates:
        if any(equivalent(word, other) for other in chosen):
            continue
        chosen.append(word)
        if len(chosen) == number:
            return [item[field] for item in chosen]
    raise ValueError(f"词书无法为「{target['term']}」提供足够的不重复干扰项，请改用词量更充足的词书。")


def shuffled(values, rng):
    result = list(values)
    rng.shuffle(result)
    return result


def local_audio(term, directory):
    aiff = directory / "prompt.aiff"
    wav = directory / "prompt.wav"
    try:
        for command in (
            ("/usr/bin/say", "-v", "Samantha", "-r", "170", "-o", str(aiff), "--", term),
            ("/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16", str(aiff), str(wav)),
        ):
            subprocess.run(command, check=True, capture_output=True, text=True, timeout=15)
        with wave.open(str(wav), "rb") as recording:
            if not any(recording.readframes(recording.getnframes())):
                raise ValueError("录音为空")
        return "data:audio/wav;base64," + base64.b64encode(wav.read_bytes()).decode("ascii")
    except (OSError, subprocess.SubprocessError, wave.Error, ValueError) as error:
        raise ValueError("离线语音生成失败，请在 macOS 上确认 Samantha 本机语音和 afconvert 可用。") from error
    finally:
        aiff.unlink(missing_ok=True)
        wav.unlink(missing_ok=True)


def make_packet(book, sets, args, rng):
    participant = f"P{args.slot:02d}"
    order, set_for_a = allocation(args.cohort_seed, args.slot)
    assigned = [word for word_set in sets for _, word in word_set]
    distractor_pool = [
        word for word in book.values()
        if not any(equivalent(word, target) for target in assigned)
    ]
    rounds = []
    probe_order = []
    with TemporaryDirectory(prefix="words-killer-pilot-") as temporary:
        for arm in order:
            word_set = sets[set_for_a if arm == "A" else 1 - set_for_a]
            pair = [word for _, word in word_set[:2]]
            pair_options = [word["translation"] for word in pair]
            pair_options += choose_distractors(distractor_pool, pair[0], "translation", 2, rng)
            items = []
            for index, (due, word) in enumerate(word_set):
                meaning = word["translation"]
                term = word["term"]
                terms = choose_distractors(distractor_pool, word, "term", 3, rng)
                probe_terms = choose_distractors(distractor_pool, word, "term", 3, rng, previously_used=terms)
                if set(probe_terms) == set(terms):
                    raise ValueError(f"词书无法为「{term}」提供独立的次日选项，请改用词量更充足的词书。")
                item = {
                    "id": word["id"],
                    "term": term,
                    "meaning": meaning,
                    "due_at": due.isoformat(),
                    "meaning_options": shuffled([meaning] + choose_distractors(distractor_pool, word, "translation", 3, rng), rng),
                    "term_options": shuffled([term] + terms, rng),
                    "d1_options": shuffled([term] + probe_terms, rng),
                }
                if index in (3, 5):
                    item["audio"] = local_audio(term, Path(temporary))
                items.append(item)
                probe_order.append(word["id"])
            rounds.append({
                "arm": arm,
                "round_id": f"{participant}-{arm}",
                "pair_options": shuffled(pair_options, rng),
                "items": items,
            })
    return {
        "participant_id": participant,
        "order": order,
        "day0": args.day.isoformat(),
        "day1": (args.day + timedelta(days=1)).isoformat(),
        "rehearsal": args.rehearsal,
        "rounds": rounds,
        "probe_order": shuffled(probe_order, rng),
    }


def write_packet(packet, packet_path, assignment_path):
    created = []
    try:
        with packet_path.open("x", encoding="utf-8") as output:
            created.append(packet_path)
            json.dump(packet, output, ensure_ascii=False)
            output.write("\n")
        with assignment_path.open("x", encoding="utf-8", newline="") as output:
            created.append(assignment_path)
            writer = csv.writer(output)
            writer.writerow(ASSIGNMENT_FIELDS)
            for block in packet["rounds"]:
                for item in block["items"]:
                    writer.writerow((packet["participant_id"], block["round_id"], block["arm"], packet["order"], item["id"], item["due_at"]))
    except OSError:
        for path in created:
            path.unlink(missing_ok=True)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slot", type=int, choices=range(1, 13), required=True)
    parser.add_argument("--cohort-seed", required=True)
    parser.add_argument("--day", type=date.fromisoformat, required=True)
    parser.add_argument("--probe-by", required=True, metavar="HH:MM")
    parser.add_argument("--book", type=Path, default=CORE_BOOK)
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--backup", type=Path)
    mode.add_argument("--rehearsal", action="store_true")
    args = parser.parse_args()
    try:
        if not re.fullmatch(r"[0-9]{2}:[0-9]{2}", args.probe_by):
            raise ValueError("--probe-by 使用 HH:MM")
        cutoff = datetime.combine(args.day + timedelta(days=1), time.fromisoformat(args.probe_by), tzinfo=TAIPEI)
        packet_path = args.output / "participant.json"
        assignment_path = args.output / "assignment.csv"
        if packet_path.exists() or assignment_path.exists():
            raise ValueError("输出目录已有试用文件，请使用新目录。")
        book = read_book(args.book)
        groups = candidate_groups(book, args.backup, args.day, cutoff)
        rng = random.Random(f"{args.cohort_seed}:words:{args.slot}")
        packet = make_packet(book, match_sets(groups, rng), args, rng)
        args.output.mkdir(parents=True, exist_ok=True)
        write_packet(packet, packet_path, assignment_path)
    except (OSError, KeyError, TypeError, ValueError) as error:
        parser.exit(2, f"{error}\n")
    print(f"{packet['participant_id']} {packet['order']}: {args.output}")


if __name__ == "__main__":
    main()
