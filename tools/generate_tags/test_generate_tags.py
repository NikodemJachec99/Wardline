"""Tests for generate_tags.py. Run: python3 -m unittest discover tools/generate_tags"""

import csv
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import generate_tags as gt  # noqa: E402


class GenerateTagsTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = pathlib.Path(tmp.name)

    def write_csv(self, rows):
        p = self.tmp / "in.csv"
        with p.open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["patient_code", "name"])
            w.writerows(rows)
        return p

    def test_demo_data_is_valid(self):
        tags = gt.build_tags(gt.DEFAULT_INPUT)
        patients = [t for t in tags if t.kind == "patient"]
        self.assertGreater(len(patients), 0)
        for t in patients:
            self.assertRegex(t.payload, gt.CODE_RE)

    def test_test_tags_are_appended(self):
        tags = gt.build_tags(self.write_csv([["HPT-7K3M9QX2", "Jan Kowalczyk"]]))
        payloads = [t.payload for t in tags if t.kind == "test"]
        self.assertEqual(payloads[:3], ["HPT-ZZZZZZZZ", "HELLO", ""])
        self.assertTrue(payloads[3].startswith("https://"))

    def test_code_is_normalized_like_the_app(self):
        tags = gt.build_tags(self.write_csv([[" hpt-7k3m9qx2\n", "Jan"]]))
        self.assertEqual(tags[0].payload, "HPT-7K3M9QX2")

    def test_rejects_invalid_code(self):
        # O is not Crockford Base32 and must not be read as 0.
        with self.assertRaises(ValueError):
            gt.build_tags(self.write_csv([["HPT-7K3M9QXO", "Jan"]]))

    def test_rejects_duplicates(self):
        rows = [["HPT-7K3M9QX2", "A"], ["hpt-7k3m9qx2", "B"]]
        with self.assertRaises(ValueError):
            gt.build_tags(self.write_csv(rows))

    def test_unknown_test_id_must_not_be_a_patient(self):
        with self.assertRaises(ValueError):
            gt.build_tags(self.write_csv([["HPT-ZZZZZZZZ", "Jan"]]))

    def test_csv_holds_only_id_as_payload_and_keeps_polish_names(self):
        out = self.tmp / "out"
        self.assertEqual(gt.main(["--input", str(self.write_csv(
            [["HPT-4QW8N2KD", "Maria Zielińska"]])), "--out", str(out), "--csv-only"]), 0)
        with (out / "tags.csv").open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(rows[0]["patient_code"], "HPT-4QW8N2KD")
        self.assertEqual(rows[0]["name"], "Maria Zielińska")
        self.assertEqual(len(rows), 1 + 4)

    def test_pdf_is_written(self):
        try:
            import reportlab  # noqa: F401
        except ImportError:
            self.skipTest("reportlab not installed")
        out = self.tmp / "out"
        self.assertEqual(gt.main(["--out", str(out)]), 0)
        self.assertTrue((out / "qr_sheet.pdf").read_bytes().startswith(b"%PDF"))


if __name__ == "__main__":
    unittest.main()
