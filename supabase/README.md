# supabase/

Lokalny backend Supabase. Szczegóły i kolejność migracji: [docs/BACKEND.md](../docs/BACKEND.md), PLAN §5.

```
config.toml     konfiguracja lokalnego stacku (supabase init)
migrations/     0001_schema.sql, 0002_rls.sql, 0003_rpc.sql, 0004_realtime.sql, ...
seed.sql        oddziały + fikcyjni pacjenci (dane, nie RLS)
tests/          pgTAP: RLS, RPC, konflikty, idempotencja
functions/      Edge Functions: admin-set-role, demo-reset (rozszerzenia)
```

```bash
supabase start
supabase db reset
supabase test db
```

CI (`supabase-db-test`) uruchamia `supabase start` + `supabase test db`, gdy w `migrations/` jest choć jeden plik `.sql`.
