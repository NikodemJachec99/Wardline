#!/usr/bin/env python3
"""Generate printable patient tags: tags.csv and qr_sheet.pdf (PLAN §14, §9.13).

SIMULATION ONLY: every name and ID is fictional.

- tags.csv     patient_code, name (for a human cross-check), kind, expected scan result
- qr_sheet.pdf one card per tag: QR, the code as text, the fictional name and
               a marked spot for an NTAG213 sticker

The QR (and the NFC tag) holds ONLY the ID `HPT-XXXXXXXX` (docs/ID_FORMAT.md).
Names are printed next to it for people, never encoded.

Patients come from app/assets/demo/sample-data.json by default (the same data
the app's demo mode shows). Once supabase/seed.sql exists, export the patients
to CSV (columns: patient_code, name) and pass it with --input.

Test tags for acceptance test 6 are always appended: an unknown ID
(HPT-ZZZZZZZZ), a wrong format (HELLO), an empty tag and a URL.

Usage (from the repo root):
  python3 -m pip install -r tools/generate_tags/requirements.txt
  python3 tools/generate_tags/generate_tags.py
  python3 tools/generate_tags/generate_tags.py --input patients.csv --out /tmp/tags
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import sys
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
DEFAULT_INPUT = ROOT / "app" / "assets" / "demo" / "sample-data.json"
DEFAULT_OUT = ROOT / "tools" / "generate_tags" / "out"
FONT_DIR = ROOT / "app" / "assets" / "fonts"

# Same rule as PatientCode.tryParse and the CHECK constraint in the database.
CODE_RE = re.compile(r"^HPT-[0-9A-HJKMNP-TV-Z]{8}$")

# Expected results use the app copy (design/handoff/copy.md, section Scan).
EXPECT_FOUND = "opens patient profile"
EXPECT_UNKNOWN = "scan.unknown ({code} isn't registered)"
EXPECT_INVALID = "scan.invalid (no Wardline patient ID)"


@dataclass(frozen=True)
class Tag:
    payload: str  # exactly what goes into the QR and the NDEF Text record
    name: str  # printed for people only, never encoded
    kind: str  # "patient" or "test"
    expected: str


def normalize(raw: str) -> str:
    """Mirror PatientCode.tryParse: trim and upper-case, nothing else."""
    return raw.strip().upper()


def load_patients(path: pathlib.Path) -> list[Tag]:
    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        rows = [(p["code"], p["name"]) for p in data["patients"]]
    elif path.suffix.lower() == ".csv":
        with path.open(encoding="utf-8-sig", newline="") as f:
            rows = [(r["patient_code"], r["name"]) for r in csv.DictReader(f)]
    else:
        raise ValueError(f"{path}: expected .json or .csv")

    tags: list[Tag] = []
    seen: set[str] = set()
    for raw, name in rows:
        code = normalize(raw)
        if not CODE_RE.match(code):
            raise ValueError(f"{path}: {raw!r} is not a valid patient code")
        if code in seen:
            raise ValueError(f"{path}: duplicate patient code {code}")
        seen.add(code)
        tags.append(Tag(code, name.strip(), "patient", EXPECT_FOUND))
    if not tags:
        raise ValueError(f"{path}: no patients")
    return tags


def test_tags(patient_codes: set[str]) -> list[Tag]:
    unknown = "HPT-ZZZZZZZZ"
    if unknown in patient_codes:
        raise ValueError(f"{unknown} must not belong to a real patient")
    return [
        Tag(unknown, "Test: unknown ID", "test",
            EXPECT_UNKNOWN.format(code=unknown)),
        Tag("HELLO", "Test: wrong format", "test", EXPECT_INVALID),
        Tag("", "Test: empty tag", "test", EXPECT_INVALID),
        Tag("https://example.com/HPT-7K3M9QX2", "Test: URL instead of ID",
            "test", EXPECT_INVALID),
    ]


def build_tags(input_path: pathlib.Path) -> list[Tag]:
    patients = load_patients(input_path)
    return patients + test_tags({t.payload for t in patients})


def write_csv(tags: list[Tag], path: pathlib.Path) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["patient_code", "name", "kind", "expected_scan_result"])
        for t in tags:
            w.writerow([t.payload, t.name, t.kind, t.expected])


# --- PDF -------------------------------------------------------------------

def write_pdf(tags: list[Tag], path: pathlib.Path) -> None:
    # Imported here so the CSV part (and its tests) work without reportlab.
    from reportlab.graphics import renderPDF
    from reportlab.graphics.barcode.qr import QrCodeWidget
    from reportlab.graphics.shapes import Drawing
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas

    # Inter (bundled with the app) has Polish glyphs; Helvetica does not.
    pdfmetrics.registerFont(TTFont("Inter", str(FONT_DIR / "Inter-Regular.ttf")))
    pdfmetrics.registerFont(TTFont("Inter-Bold", str(FONT_DIR / "Inter-Bold.ttf")))

    page_w, page_h = A4
    margin, gap = 12 * mm, 6 * mm
    cols, rows = 2, 4
    header_h = 14 * mm
    card_w = (page_w - 2 * margin - (cols - 1) * gap) / cols
    card_h = (page_h - 2 * margin - header_h - (rows - 1) * gap) / rows
    qr_size = 38 * mm
    nfc_d = 25 * mm  # round NTAG213 sticker
    per_page = cols * rows
    pages = (len(tags) + per_page - 1) // per_page

    c = canvas.Canvas(str(path), pagesize=A4)
    c.setTitle("Wardline patient tags (SIMULATION ONLY)")

    for i, tag in enumerate(tags):
        slot = i % per_page
        if slot == 0:
            if i:
                c.showPage()
            c.setFont("Inter-Bold", 12)
            c.drawString(margin, page_h - margin - 5 * mm, "Wardline · patient tags")
            c.setFont("Inter", 8)
            c.drawRightString(
                page_w - margin, page_h - margin - 5 * mm,
                f"SIMULATION ONLY · fictional data · page {i // per_page + 1}/{pages}",
            )
        col, row = slot % cols, slot // cols
        x = margin + col * (card_w + gap)
        y = page_h - margin - header_h - (row + 1) * card_h - row * gap

        # Cut line.
        c.setDash(2, 2)
        c.setLineWidth(0.5)
        c.roundRect(x, y, card_w, card_h, 3 * mm)
        c.setDash()

        pad = 5 * mm
        qr_x, qr_y = x + pad, y + card_h - pad - qr_size
        if tag.payload:
            widget = QrCodeWidget(tag.payload, barLevel="M")
            bx0, by0, bx1, by1 = widget.getBounds()
            d = Drawing(qr_size, qr_size,
                        transform=[qr_size / (bx1 - bx0), 0, 0,
                                   qr_size / (by1 - by0), 0, 0])
            d.add(widget)
            renderPDF.draw(d, c, qr_x, qr_y)
        else:
            c.setDash(1, 2)
            c.rect(qr_x, qr_y, qr_size, qr_size)
            c.setDash()
            c.setFont("Inter", 7)
            c.drawCentredString(qr_x + qr_size / 2, qr_y + qr_size / 2, "no QR: empty tag")

        # Text under the QR: the code exactly as encoded, then the name.
        c.setFont("Inter-Bold", 11)
        c.drawString(qr_x, qr_y - 6 * mm, tag.payload or "(empty)")
        c.setFont("Inter", 9)
        c.drawString(qr_x, qr_y - 11 * mm, tag.name)
        if tag.kind == "test":
            c.setFont("Inter", 7)
            c.drawString(qr_x, qr_y - 15 * mm, f"Expect: {tag.expected}")

        # NFC sticker spot.
        cx = x + card_w - pad - nfc_d / 2
        cy = y + card_h - pad - nfc_d / 2
        c.setDash(3, 2)
        c.circle(cx, cy, nfc_d / 2)
        c.setDash()
        c.setFont("Inter", 7)
        c.drawCentredString(cx, cy + 1 * mm, "NTAG213")
        c.drawCentredString(cx, cy - 2.5 * mm, "NDEF Text")
        if tag.kind == "patient":
            hint = "write the same ID"
        elif tag.payload:
            hint = "write the text above"
        else:
            hint = "leave the tag empty"
        c.drawCentredString(cx, cy - nfc_d / 2 - 4 * mm, hint)

    c.save()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--input", type=pathlib.Path, default=DEFAULT_INPUT,
                    help="patients as .json (sample-data format) or .csv "
                         "(patient_code,name); default: app demo data")
    ap.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT,
                    help="output directory (default: tools/generate_tags/out)")
    ap.add_argument("--csv-only", action="store_true",
                    help="skip the PDF (no reportlab needed)")
    args = ap.parse_args(argv)

    try:
        tags = build_tags(args.input)
    except (OSError, ValueError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    write_csv(tags, args.out / "tags.csv")
    print(f"wrote {args.out / 'tags.csv'} ({len(tags)} tags)")
    if not args.csv_only:
        write_pdf(tags, args.out / "qr_sheet.pdf")
        print(f"wrote {args.out / 'qr_sheet.pdf'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
