# Uprawnienia

> Stub. Uzupełnia osoba odpowiedzialna w ramach swojego issue. Źródło: [PLAN.md](PLAN.md#22-macierz-uprawnień-egzekwowana-w-bazie).

## Do opisania

- Macierz Nurse / Doctor / Admin / Anon (PLAN §2.2).
- Jak backend to egzekwuje: RLS `SELECT` dla `authenticated`, `REVOKE INSERT/UPDATE/DELETE`, RPC `SECURITY DEFINER` z kontrolą roli, triggery append-only.
- Test „bypass UI”: curl z JWT pielęgniarki na `set_patient_status` → PT403, `PATCH /rest/v1/patients` → permission denied, bez tokenu → 401.

