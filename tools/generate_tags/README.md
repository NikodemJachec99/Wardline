# tools/generate_tags

> SIMULATION ONLY. Wszystkie imiona i ID są fikcyjne.

Generuje materiały do druku i kodowania tagów (PLAN §14, §9.13):

- `out/tags.csv`: `patient_code`, `name` (imię tylko do kontroli przez człowieka), `kind` (`patient` / `test`), `expected_scan_result`.
- `out/qr_sheet.pdf`: A4, 8 kart na stronę. Każda karta: QR, kod tekstem, fikcyjne imię i zaznaczone miejsce na naklejkę NTAG213 (Ø 25 mm). Linia przerywana to linia cięcia.

**QR i tag NFC zawierają wyłącznie identyfikator `HPT-XXXXXXXX`** ([ID_FORMAT.md](../../docs/ID_FORMAT.md)). Imię jest tylko nadrukowane obok, nigdy zakodowane. `out/` jest w `.gitignore`.

## Uruchomienie

Z katalogu głównego repo (Python 3.10+):

```bash
python3 -m pip install -r tools/generate_tags/requirements.txt   # reportlab, jednorazowo
python3 tools/generate_tags/generate_tags.py
```

Opcje:

| Flaga | Domyślnie | Co robi |
|---|---|---|
| `--input PLIK` | `app/assets/demo/sample-data.json` | Pacjenci z JSON-a (format danych demo) albo z CSV z kolumnami `patient_code,name`. |
| `--out KATALOG` | `tools/generate_tags/out` | Gdzie zapisać wyniki. |
| `--csv-only` | wyłączone | Tylko CSV, bez PDF (nie wymaga `reportlab`). |

Domyślnie pacjenci pochodzą z danych demo aplikacji, więc wydrukowane kody otwierają pacjentów w trybie demo. Gdy powstanie `supabase/seed.sql`, wyeksportuj pacjentów do CSV i podaj go przez `--input`, np.:

```sql
\copy (select patient_code, first_name || ' ' || last_name as name from patients order by patient_code) to 'patients.csv' csv header
```

Skrypt waliduje każdy kod tą samą regułą co aplikacja i baza (`^HPT-[0-9A-HJKMNP-TV-Z]{8}$`, po `trim` i wielkich literach) i przerywa przy błędnym albo zduplikowanym kodzie.

## Tagi testowe (test akceptacyjny 6)

Zawsze dopisywane na końcu CSV i PDF:

| Payload | Po co | Oczekiwany wynik w aplikacji |
|---|---|---|
| `HPT-ZZZZZZZZ` | poprawny format, brak pacjenta | `scan.unknown`: „HPT-ZZZZZZZZ isn't registered” |
| `HELLO` | zły format | `scan.invalid` |
| *(pusty)* | pusty tag NFC, karta bez QR | `scan.invalid` |
| `https://example.com/HPT-7K3M9QX2` | URL zamiast ID | `scan.invalid` |

Skrypt odmówi działania, jeśli `HPT-ZZZZZZZZ` należy do prawdziwego pacjenta.

## Kodowanie tagów NFC

1. Wydrukuj `qr_sheet.pdf` w skali 100% (bez „dopasuj do strony”).
2. Naklej NTAG213 na kółko na karcie.
3. W aplikacji **NFC Tools** (Android/iOS): *Write → Add a record → Text*, wpisz dokładnie payload z karty (dla pustego tagu: *Other → Erase tag* albo zapis pustej wiadomości), *Write* i przyłóż tag. Nie używaj rekordu *URL*: aplikacja czyta tylko rekord NDEF **Text**.
4. Sprawdź: skan tagu i QR z tej samej karty w aplikacji ma otworzyć tego samego pacjenta. Kolumna `expected_scan_result` w CSV mówi, czego się spodziewać.

## Testy

```bash
python3 -m unittest discover tools/generate_tags -v
```
