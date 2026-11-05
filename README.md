# Wardline

*Hospital Patient Tracking System*

[![CI](https://github.com/NikodemJachec99/Wardline/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/NikodemJachec99/Wardline/actions/workflows/ci.yml)

Mobile app for hospital staff: scan a patient wristband (NFC or QR) to open the record, let a nurse confirm a ward transfer and a doctor change the status, and see every change live on a second device.

> **SIMULATION ONLY — fictional data.** No real patient data, ever. No secrets in this repository.

## Stack

| Layer | Tech |
|---|---|
| App | Flutter + Dart, Riverpod, go_router, Drift (SQLite cache) |
| Backend | Supabase: Postgres, Auth, RLS, RPC, Realtime |
| Identification | `nfc_manager` (NTAG213, NDEF Text), `mobile_scanner` (QR) |
| CI | GitHub Actions: analyze, tests, Android APK, iOS build (no codesign), pgTAP |

Core rules: a scan only **opens** a patient, it never changes the location. A transfer is an atomic RPC (`transfer_patient`) with idempotency (`client_request_id`) and conflict control (`expected_version`). Permissions are enforced by the database (RLS + RPC), the UI only mirrors them.

## Repository layout

```
app/        Flutter app (lib/app, lib/core, lib/data, lib/features/<feature>)
supabase/   config.toml, migrations/, seed.sql, tests/ (pgTAP), functions/
tools/      generate_tags/ (CSV + QR PDF), concurrency_test/
docs/       PLAN.md (source of truth) + architecture, backend, permissions, testing, demo
.github/    CI, templates, Dependabot, CODEOWNERS
```

## Requirements

| Tool | Version |
|---|---|
| Flutter | **3.47.9** stable (pinned in CI, use the same locally) |
| Dart | 3.13.7 (bundled with Flutter) |
| JDK | 17 (Android Gradle Plugin 9.x) |
| Xcode | latest stable, macOS only, for iOS builds |
| Supabase CLI | 3.0.0 (+ Docker for the local stack) |

## Quick start

```bash
git clone https://github.com/NikodemJachec99/Wardline.git
cd Wardline/app
cp .env.example.json .env.json   # fill SUPABASE_URL and SUPABASE_ANON_KEY (anon key only!)
flutter pub get
flutter run --dart-define-from-file=.env.json
```

Run on a physical device: plug it in, `flutter devices`, then `flutter run -d <id> --dart-define-from-file=.env.json`. NFC needs a real phone. iOS also needs the NFC entitlement, see [docs/BACKEND.md](docs/BACKEND.md#ios-nfc-entitlement-krok-ręczny).

Local backend (once migrations exist):

```bash
supabase start        # from the repo root, needs Docker
supabase db reset     # migrations + seed.sql
supabase test db      # pgTAP
```

`.env.json` is git-ignored. The `service_role` key never goes into the app or the repo.

## Team workflow (short)

1. Pick an issue from the **Ready** column on the [project board](https://github.com/users/NikodemJachec99/projects/4).
2. Branch `feat/<issue>-short-name` (or `fix/`, `chore/`, `docs/`, `test/`, `ci/`).
3. Small PR with `Closes #<issue>`, title as a Conventional Commit.
4. Green `ci-ok` + review, then squash merge.

Details: [CONTRIBUTING.md](CONTRIBUTING.md). Plan, priorities and acceptance tests: [docs/PLAN.md](docs/PLAN.md).

## License

[MIT](LICENSE)
