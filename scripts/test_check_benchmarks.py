"""Use temporary copies so committed timing evidence is never changed."""
import csv
from pathlib import Path
import shutil
import tempfile
import unittest
from check_benchmarks import check

class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name) / "baseline"
        shutil.copytree(Path(__file__).resolve().parents[1] / "benchmarks/results/baseline", self.folder)

    def test_original_evidence(self):
        self.assertEqual(check(self.folder), [])

    def test_missing_plan(self):
        (self.folder / "R01.txt").unlink()
        self.assertTrue(check(self.folder))

    def test_changed_execution_time(self):
        path = self.folder / "R01.txt"
        import re
        path.write_text(re.sub(r"Execution Time: [0-9.]+", "Execution Time: 999999", path.read_text(), count=1))
        self.assertTrue(check(self.folder))

    def test_duplicate_query(self):
        path = self.folder / "summary.csv"
        with path.open(newline="") as f:
            reader = csv.DictReader(f); fields = reader.fieldnames; rows = list(reader)
        rows[-1] = rows[0]
        with path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(rows)
        self.assertTrue(check(self.folder))

    def test_missing_run(self):
        path = self.folder / "R01.txt"
        path.write_text(path.read_text().split("=== R01 run 3 ===")[0])
        self.assertTrue(check(self.folder))

    def test_nonfinite_summary(self):
        path = self.folder / "summary.csv"
        with path.open(newline="") as f:
            reader = csv.DictReader(f); fields = reader.fieldnames; rows = list(reader)
        rows[0]["avg_ms"] = "NaN"
        with path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(rows)
        self.assertTrue(check(self.folder))

if __name__ == "__main__":
    unittest.main()
