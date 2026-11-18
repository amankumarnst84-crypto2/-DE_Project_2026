#!/usr/bin/env python3
"""Check saved evidence, without connecting to or changing a database."""
import csv
from decimal import Decimal, InvalidOperation
from pathlib import Path
import re
import sys

IDS = [f"R{i:02}" for i in range(1, 26)] + [f"W{i:02}" for i in range(1, 6)]

def check(folder):
    errors = []
    try:
        with (folder / "summary.csv").open(newline="") as stream:
            reader = csv.DictReader(stream)
            required = {"query_id", "type", "avg_ms", "median_ms", "min_ms", "max_ms"}
            if not required.issubset(reader.fieldnames or []):
                return [f"{folder}: missing summary columns"]
            rows = list(reader)
    except OSError as exc:
        return [str(exc)]
    ids = [row["query_id"] for row in rows]
    if sorted(ids) != sorted(IDS):
        errors.append(f"{folder}: expected each of R01–R25 and W01–W05 exactly once")
    for row in rows:
        qid = row["query_id"]
        if qid not in IDS:
            continue
        path = folder / f"{qid}.txt"
        try:
            text = path.read_text()
            markers = re.findall(r"^=== (\w+) run (\d+) ===$", text, re.M)
            if markers != [(qid, str(i)) for i in range(1, 4)]:
                raise ValueError("expected three ordered, matching run headers")
            chunks = re.split(r"^=== \w+ run \d+ ===$", text, flags=re.M)[1:]
            values = []
            for chunk in chunks:
                times = re.findall(r"^Execution Time: ([0-9]+(?:\.[0-9]+)?) ms$", chunk, re.M)
                if len(times) != 1:
                    raise ValueError("each run must have exactly one execution time")
                if re.search(r"(?:ERROR|FATAL):", chunk):
                    raise ValueError("plan contains a database error")
                values.append(Decimal(times[0]))
            expected = {"avg_ms": sum(values) / 3, "median_ms": sorted(values)[1],
                        "min_ms": min(values), "max_ms": max(values)}
            if row["type"] != ("READ" if qid.startswith("R") else "WRITE"):
                raise ValueError("wrong query type")
            for field, actual in expected.items():
                recorded = Decimal(row[field])
                if not recorded.is_finite() or recorded < 0:
                    raise ValueError(f"{field}: invalid number")
                if abs(recorded - actual) > Decimal("0.000501"):
                    raise ValueError(f"{field}: summary {recorded}, raw plans {actual}")
        except (OSError, ValueError, InvalidOperation, TypeError) as exc:
            errors.append(f"{path}: {exc}")
    return errors

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    folders = [Path(x) for x in sys.argv[1:]] or [root / "benchmarks/results" / x for x in ("baseline", "optimized")]
    failures = [error for folder in folders for error in check(folder)]
    if failures:
        print("\n".join(failures), file=sys.stderr)
        sys.exit(1)
    print(f"PASS: {len(folders)} result sets; 30 queries and 90 recorded runs per set")
