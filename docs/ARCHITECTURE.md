# Architektura

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#4-architektura).

## Do opisania

- Warstwy: UI → Riverpod providers/controllers → repozytoria → Supabase / Drift / adaptery NFC i QR.
- Struktura `app/lib`: `app/` (router, theme), `core/` (env, błędy `PTxxx`, parser ID), `data/` (repozytoria, DTO, Drift), `features/<feature>/`.
- Flow skan → quick summary → transfer → RPC → realtime na drugim urządzeniu (diagram).
- Mapowanie błędów `PT401/403/404/409/422` na komunikaty UI.

