# Format identyfikatora

Źródło: [PLAN.md §5.5](PLAN.md#55-format-identyfikatora-id_formatmd). Kod: `app/lib/core/id/patient_code.dart` (`PatientCode.tryParse`), testy: `app/test/core/id/patient_code_test.dart`.

> SIMULATION ONLY. Wszystkie ID w repo są fikcyjne.

## Format

`HPT-` + 8 znaków **Crockford Base32**: cyfry `0-9` i litery bez `I`, `L`, `O`, `U` (nie mylą się z `1` i `0`, nie da się ułożyć przypadkiem słowa).

```
^HPT-[0-9A-HJKMNP-TV-Z]{8}$
```

Przykład: `HPT-7K3M9QXA`. 32^8 ≈ 1,1 biliona kombinacji, więc losowe ID się nie powtarzają.

## Jedna walidacja dla NFC i QR

`PatientCode.tryParse(raw)`:

1. obcina białe znaki na brzegach (skanery i rekordy NDEF dokładają `\n`),
2. zamienia na wielkie litery (`hpt-7k3m9qxa` → `HPT-7K3M9QXA`),
3. sprawdza regex. Nie pasuje → `null` → UI pokazuje "invalid tag" (`design/handoff/copy.md`, sekcja Scan).

Nic nie zgadujemy: `O` nie jest czytane jako `0`, spacje w środku, URL-e i dopiski odrzucamy.

Pasuje → lookup w bazie (`select … where patient_code = :code`, tylko odczyt). Brak rekordu → "unknown ID". **Skan nigdy niczego nie zapisuje.**

## Nośniki

- **NFC:** NTAG213, jeden rekord NDEF **Text** (`en`, UTF-8) z samym ID. UID chipu nie jest identyfikatorem i jest ignorowany.
- **QR:** ten sam string, ECC M.

## Zakazane na tagach i w QR

Imiona, schorzenia, daty, tokeny, URL-e, cokolwiek poza ID.

## Serwer

Ta sama reguła w bazie: `CHECK (patient_code ~ '^HPT-[0-9A-HJKMNP-TV-Z]{8}$')` na `patients.patient_code` (PLAN §5.1). Klient waliduje tylko po to, żeby szybko pokazać błąd; decyduje serwer.
