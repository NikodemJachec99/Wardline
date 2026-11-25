# tools/generate_tags

> SIMULATION ONLY. Every name and ID is fictional.

Generates print and tag-encoding material (PLAN §14, §9.13):

- `out/tags.csv`: `patient_code`, `name` (for a human cross-check only), `kind` (`patient` / `test`), `expected_scan_result`.
- `out/qr_sheet.pdf`: A4, 8 cards per page. Each card has the QR, the code as text, the fictional name and a marked spot for an NTAG213 sticker (Ø 25 mm). The dashed line is the cut line.

**The QR and the NFC tag hold only the ID `HPT-XXXXXXXX`** ([ID_FORMAT.md](../../docs/ID_FORMAT.md)). The name is printed next to it, never encoded. `out/` is git-ignored.

## Running

From the repo root (Python 3.10+):

```bash
python3 -m pip install -r tools/generate_tags/requirements.txt   # reportlab, once
python3 tools/generate_tags/generate_tags.py
```

Options:

| Flag | Default | What it does |
|---|---|---|
| `--input FILE` | `app/assets/demo/sample-data.json` | Patients from JSON (demo data format) or from CSV with columns `patient_code,name`. |
| `--out DIR` | `tools/generate_tags/out` | Where to write the output. |
| `--csv-only` | off | CSV only, no PDF (does not need `reportlab`). |

By default patients come from the app's demo data, so the printed codes open patients in demo mode. Once `supabase/seed.sql` exists, export the patients to CSV and pass it with `--input`, for example:

```sql
\copy (select patient_code, first_name || ' ' || last_name as name from patients order by patient_code) to 'patients.csv' csv header
```

The script validates every code with the same rule as the app and the database (`^HPT-[0-9A-HJKMNP-TV-Z]{8}$`, after trimming and upper-casing) and stops on an invalid or duplicate code.

## Test tags (acceptance test 6)

Always appended to the end of the CSV and the PDF:

| Payload | Purpose | Expected result in the app |
|---|---|---|
| `HPT-ZZZZZZZZ` | valid format, no such patient | `scan.unknown`: "HPT-ZZZZZZZZ isn't registered" |
| `HELLO` | wrong format | `scan.invalid` |
| *(empty)* | empty NFC tag, card without a QR | `scan.invalid` |
| `https://example.com/HPT-7K3M9QX2` | URL instead of an ID | `scan.invalid` |

The script refuses to run if `HPT-ZZZZZZZZ` belongs to a real patient.

## Encoding the NFC tags

1. Print `qr_sheet.pdf` at 100% scale (no "fit to page").
2. Stick an NTAG213 on the circle on each card.
3. In **NFC Tools** (Android/iOS): *Write → Add a record → Text*, enter exactly the payload from the card (for the empty tag: *Other → Erase tag*, or write an empty message), tap *Write* and hold the tag to the phone. Do not use a *URL* record: the app only reads an NDEF **Text** record.
4. Check: scanning the tag and the QR from the same card must open the same patient. The `expected_scan_result` column in the CSV says what to expect.

## Tests

```bash
python3 -m unittest discover tools/generate_tags -v
```
