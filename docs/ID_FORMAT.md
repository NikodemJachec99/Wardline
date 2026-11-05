# Format identyfikatora

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#55-format-identyfikatora-id_formatmd).

## Do opisania

- `HPT-` + 8 znaków Crockford Base32, regex `^HPT-[0-9A-HJKMNP-TV-Z]{8}$`.
- NFC: NTAG213, jeden rekord NDEF Text (`en`). QR: ten sam string, ECC M.
- Zakazane: imiona, schorzenia, daty, tokeny, URL. UID chipu nie jest identyfikatorem.
- Walidacja klient (regex) i serwer (`CHECK` + lookup).

