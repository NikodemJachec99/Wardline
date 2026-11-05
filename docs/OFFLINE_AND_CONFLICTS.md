# Offline i konflikty

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#6-offline-cache-i-konflikty-offline_and_conflictsmd).

## Do opisania

- Cache Drift, baner offline, etykieta „Dane z cache · sync HH:MM”.
- Blokada zapisów offline (bez cichego kolejkowania).
- Idempotencja: `client_request_id`, timeout → „Sprawdź” z tym samym ID.
- Konflikty: `expected_version` → PT409 → ekran konfliktu → odświeżenie. Decyzja: wspólna `version` dla statusu i lokalizacji.
- Realtime bez replay → pełny refetch po reconnect.

