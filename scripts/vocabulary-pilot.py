#!/usr/bin/env python3
"""Calculate the offline trial metrics defined in VOCABULARY_PILOT.md."""

import argparse
import csv
import json
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from fractions import Fraction
from pathlib import Path
from zoneinfo import ZoneInfo


PILOT_TIMEZONE = ZoneInfo("Asia/Taipei")
ARMS = ("A", "B")


def read_rows(directory, filename):
    with (directory / filename).open(encoding="utf-8-sig", newline="") as source:
        return list(csv.DictReader(source))


def timestamp(value):
    parsed = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    if parsed.utcoffset() is None:
        raise ValueError("Timestamps must include a UTC offset")
    return parsed.astimezone(PILOT_TIMEZONE)


def rate(numerator, denominator):
    return Fraction(numerator, denominator) if denominator else None


def metric(numerator, denominator):
    ratio = rate(numerator, denominator)
    return {"numerator": numerator, "denominator": denominator, "rate": float(ratio) if ratio is not None else None}


def calculate(directory, through):
    assignments = {}
    rounds = {}
    dates = {}
    orders = {}
    sizes = Counter()
    for row in read_rows(directory, "assignment.csv"):
        participant, word, round_id, arm = (row[key] for key in ("participant_id", "word_id", "round_id", "arm"))
        due = timestamp(row["frozen_due_at"])
        order = row["order"]
        key = (participant, word)
        round_key = (participant, round_id)
        if not all(key) or not round_id or key in assignments or arm not in ARMS:
            raise ValueError("Invalid or repeated participant-word assignment")
        if rounds.setdefault(round_key, arm) != arm or dates.setdefault(participant, due.date()) != due.date():
            raise ValueError("Each round must have one arm and each participant one frozen probe date")
        if order not in ("AB", "BA") or orders.setdefault(participant, order) != order:
            raise ValueError("Each participant must have one assigned order: AB or BA")
        assignments[key] = (arm, due)
        sizes[round_key] += 1
    for participant in dates:
        participant_arms = sorted(arm for key, arm in rounds.items() if key[0] == participant)
        if participant_arms != list(ARMS):
            raise ValueError("Each participant must be assigned one A round and one B round")
    if any(size != 6 for size in sizes.values()):
        raise ValueError("Each assigned round must contain six distinct words")

    observed_rounds = {}
    starts = {}
    for row in read_rows(directory, "rounds.csv"):
        key = (row["participant_id"], row["round_id"])
        state = row["terminal_state"]
        start = timestamp(row["first_question_at"]) if row["first_question_at"] else None
        summary = timestamp(row["summary_seen_at"]) if row["summary_seen_at"] else None
        if key not in rounds or key in observed_rounds:
            raise ValueError("Round observations must match unique assigned rounds")
        training_day = dates[key[0]] - timedelta(days=1)
        if start and start.date() != training_day:
            raise ValueError("A round must start on D0")
        if start:
            starts[key[0], rounds[key]] = start
        if summary and start and summary.date() == training_day and summary >= start and state == "completed":
            observed_rounds[key] = "completed"
        elif not summary and ((start and state == "abandoned") or (not start and state == "not_started")):
            observed_rounds[key] = state
        else:
            raise ValueError("Inconsistent start, summary or terminal state")
    for participant, order in orders.items():
        first, second = (starts.get((participant, arm)) for arm in order)
        if first and second and first >= second:
            raise ValueError("Observed starting order differs from assigned order")

    earliest = {}
    contaminated = set()
    late = set()
    for row in read_rows(directory, "probes.csv"):
        key = (row["participant_id"], row["word_id"])
        if key not in assignments:
            raise ValueError("Probe contains a word outside the frozen assignment")
        submitted = timestamp(row["submitted_at"])
        _, due = assignments[key]
        status = row["protocol_status"]
        if status == "prior_exposure" or (status == "valid" and submitted < due):
            contaminated.add(key)
            continue
        if status == "rejected":
            continue
        if status != "valid" or row["correct"] not in ("0", "1"):
            raise ValueError("A valid probe must use correct=0 or correct=1")
        if submitted.date() != due.date():
            late.add(key)
            continue
        correct = int(row["correct"])
        previous = earliest.get(key)
        if previous and submitted == previous[0] and correct != previous[1]:
            earliest[key] = (submitted, None)
        elif previous is None or submitted < previous[0]:
            earliest[key] = (submitted, correct)

    ready = {participant for participant, due_day in dates.items() if due_day <= through}
    totals = {arm: Counter() for arm in ARMS}
    people = defaultdict(Counter)
    for key, (arm, _) in assignments.items():
        participant, _ = key
        if participant not in ready:
            continue
        counts = people[participant, arm]
        counts["assigned"] += 1
        if key in earliest and key not in contaminated:
            correct = earliest[key][1]
            if correct is None:
                raise ValueError("Conflicting answers at the first probe timestamp")
            counts["answered"] += 1
            counts["correct"] += correct
        elif key in contaminated:
            counts["contaminated"] += 1
        elif key in late:
            counts["late"] += 1
    for (_, arm), counts in people.items():
        totals[arm].update(counts)
    for key, arm in rounds.items():
        if key[0] in ready:
            totals[arm][observed_rounds.get(key, "missing_round")] += 1

    paired = []
    paired_by_order = defaultdict(list)
    paired_missing_as_wrong = []
    paired_both_started = 0
    for participant in sorted(ready):
        a, b = (people[participant, arm] for arm in ARMS)
        if a["answered"] and b["answered"]:
            difference = Fraction(b["correct"], b["answered"]) - Fraction(a["correct"], a["answered"])
            paired.append(difference)
            paired_by_order[orders[participant]].append(difference)
            if all((participant, arm) in starts for arm in ARMS):
                paired_both_started += 1
        paired_missing_as_wrong.append(Fraction(b["correct"], b["assigned"]) - Fraction(a["correct"], a["assigned"]))

    coverage = [rate(totals[arm]["answered"], totals[arm]["assigned"]) for arm in ARMS]
    start_coverage = [rate(totals[arm]["completed"] + totals[arm]["abandoned"], len(ready)) for arm in ARMS]
    completion = [rate(totals[arm]["completed"], totals[arm]["completed"] + totals[arm]["abandoned"]) for arm in ARMS]
    paired_lift = sum(paired) / len(paired) if paired else None
    sensitive_lift = sum(paired_missing_as_wrong) / len(paired_missing_as_wrong) if paired_missing_as_wrong else None
    order_lift = {order: sum(values) / len(values) for order, values in paired_by_order.items()}
    sufficient = (
        len(ready) == len(dates) and paired_both_started >= 8
        and all(len(paired_by_order[order]) >= 3 for order in ("AB", "BA"))
        and all(value is not None and value >= Fraction(4, 5) for value in coverage)
        and abs(coverage[1] - coverage[0]) <= Fraction(1, 10)
        and all(value is not None and value >= Fraction(4, 5) for value in start_coverage)
        and abs(start_coverage[1] - start_coverage[0]) <= Fraction(1, 10)
        and not any(totals[arm]["missing_round"] for arm in ARMS)
    )
    advance = (
        sufficient and paired_lift >= Fraction(1, 10) and sensitive_lift > 0
        and completion[1] - completion[0] >= -Fraction(1, 20)
        and all(value >= 0 for value in order_lift.values())
    )

    return {
        "matured_participants": len(ready),
        "pending_participants": len(dates) - len(ready),
        "paired_participants": len(paired),
        "paired_participants_who_started_both_rounds": paired_both_started,
        "paired_lift_pp": float(paired_lift * 100) if paired_lift is not None else None,
        "paired_lift_missing_as_wrong_pp": float(sensitive_lift * 100) if sensitive_lift is not None else None,
        "paired_by_order": {
            order: {"participants": len(paired_by_order[order]), "lift_pp": float(value * 100)}
            for order, value in sorted(order_lift.items())
        },
        "decision": "advance" if advance else ("hold" if sufficient else "insufficient"),
        "arms": {
            arm: {
                "next_day_accuracy": metric(c["correct"], c["answered"]),
                "next_day_coverage": metric(c["answered"], c["assigned"]),
                "missing_as_wrong_accuracy": metric(c["correct"], c["assigned"]),
                "short_practice_completion": metric(c["completed"], c["completed"] + c["abandoned"]),
                "short_practice_start_coverage": metric(c["completed"] + c["abandoned"], len(ready)),
                "contaminated_words": c["contaminated"],
                "late_only_words": c["late"],
                "other_unanswered_words": c["assigned"] - c["answered"] - c["contaminated"] - c["late"],
                "not_started_rounds": c["not_started"],
                "missing_round_observations": c["missing_round"],
            }
            for arm, c in totals.items()
        },
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--through", required=True, type=date.fromisoformat, help="Last fully observed local day")
    args = parser.parse_args()
    print(json.dumps(calculate(args.directory, args.through), ensure_ascii=False, indent=2))
