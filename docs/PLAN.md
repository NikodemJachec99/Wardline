# Hospital Patient Tracking System — pełny opis, pomysł i plan aplikacji

> Projekt: **Cross-Platform Mobile Application Development** (Dr Mirosław Latka) · zespół 3–4 osób · 8 tygodni
> Stack: **Flutter + Dart · Supabase (PostgreSQL, Auth, RLS, RPC, Realtime) · Drift · Riverpod · nfc_manager · mobile_scanner**
> Kierunek wizualny: **premium medical SaaS** (Apple Health × Linear × profesjonalny dashboard medyczny) + **interaktywna mapa szpitala 2D/3D**
> Towarzyszący plik: `Hospital_Patient_Tracking_Blueprint.html` — animowany blueprint (mapa 3D w ASCII, heatmapa, ścieżki pacjentów, live feed, dashboard, sankey, timeline dnia, demo na 2 telefonach, wireframe'y ekranów).

---

## 0. Brutalna prawda na start (przeczytaj zanim cokolwiek zakodujesz)

1. **Ta lista to robota na pół roku dla czterech osób, a macie 8 tygodni.** Da się dowieźć wszystko, ale tylko w jednej kolejności: najpierw core, potem efekty. Odwrotnie = katastrofa.
2. **Specyfikacja mówi wprost:** *„Optional features may demonstrate additional depth, but cannot compensate for missing core requirements”* oraz *„Begin extensions only after core tests pass”*. Jeśli na demo macie zajebistą mapę 3D, a transfer nie jest atomowy albo pielęgniarka może zmienić status przez curl — **oblewacie**. Prowadzący sprawdzi bypass UI, a nie to, jak ładnie się kręci budynek.
3. **Wszystko z Twojej listy jest w tym planie, nic nie wyciąłem.** Ale każda funkcja ma priorytet (P0–P3, sekcja 15). P0 musi działać na fizycznych telefonach do końca tygodnia 4 (wymóg ze specyfikacji: *scan-to-transfer workflow by the end of week 4*).
4. **Prawdziwe 3D w Flutterze na telefonie to pułapka.** Pełny silnik 3D (three.js przez WebView, flutter_scene, Unity) zje Wam 2–3 tygodnie i baterię. Rozwiązanie w tym planie: **2.5D na `Transform` + `Matrix4` z perspektywą** — piętra jako przechylone płaszczyzny, oddziały jako zwykłe widgety (działa natywny hit-testing, kliknięcia, animacje), przełączenie 2D↔3D to animacja jednej macierzy. Wygląda jak 3D, kosztuje jak 2D.
5. **Na iOS nie narysujecie własnych pulsujących pierścieni podczas odczytu NFC.** iOS pokazuje systemowy arkusz „Ready to Scan” i zasłania Wasz UI. Pierścienie robicie na ekranie „przyłóż telefon” przed sesją i efekt rozświetlenia po odczycie. Na Androidzie (reader mode) macie pełną kontrolę nad UI.
6. **NFC na iOS wymaga capability „NFC Tag Reading”** — z tego, co wiem, nie działa na darmowym koncie Personal Team, potrzebne jest płatne Apple Developer Program. **Sprawdźcie to w tygodniu 1**, a nie w tygodniu 7.
7. **„Pełny tryb offline z synchronizacją” stoi w sprzeczności z core**, który wymaga: *„Do not silently queue offline writes”*. Rozwiązanie: offline-edit jest osobnym trybem za flagą, **domyślnie wyłączonym**, z jawną kolejką widoczną dla użytkownika. Na demo core pokazujecie, że offline zapisy są zablokowane, potem (opcjonalnie) włączacie tryb rozszerzony.
8. **Supabase Realtime nie odtwarza zdarzeń, które przegapiliście.** Po każdym reconnect robicie pełny refetch. Kto o tym zapomni, będzie miał rozjechane dane na drugim telefonie dokładnie w trakcie demo.
9. Każdy członek zespołu musi umieć wytłumaczyć cały system. „To robił Kuba” na pytanie prowadzącego = minus punkty dla wszystkich.

---

## 1. Koncepcja produktu

**Jednym zdaniem:** mobilny system dla personelu szpitala, który po zeskanowaniu opaski (NFC NTAG213 lub QR) natychmiast pokazuje pacjenta, pozwala pielęgniarce świadomie zatwierdzić przeniesienie na inny oddział, lekarzowi zmienić status, a wszystkim — zobaczyć zmianę na żywo na każdym urządzeniu, na liście, dashboardzie i interaktywnej mapie szpitala.

**Główny flow (to jest serce projektu i oś demo):**

```
 [opaska NFC / QR]
        │  skan (NIE zmienia lokalizacji)
        ▼
 ┌──────────────────────┐   bottom sheet: imię, status, ostatnia lokalizacja, czas
 │ Szybkie podsumowanie │──► "Profil" | "Historia" | "Przenieś" (tylko Nurse) | "Status" (tylko Doctor)
 └──────────────────────┘
        │ "Przenieś"
        ▼
 ┌──────────────────────┐   wybór oddziału (wyszukiwarka) → wizualizacja A → B
 │ Potwierdzenie        │──► przycisk z loaderem, blokada ponownego kliknięcia
 └──────────────────────┘
        │ RPC transfer_patient (transakcja: lokalizacja + historia + version++)
        ▼
 ✓ checkmark DOPIERO po odpowiedzi backendu
        │ Supabase Realtime
        ▼
 drugi telefon: karta pacjenta podświetla się, licznik na dashboardzie się zmienia,
 punkt na mapie przesuwa się z oddziału A do B, wpis pojawia się w live feedzie
```

**Zasady, których nie łamiemy nigdy:**
- Skan otwiera rekord, **nigdy** nie zmienia lokalizacji.
- Status i lokalizacja to dwa osobne pola. *Discharged* to status, nie oddział — ostatnia lokalizacja zostaje jako informacja historyczna.
- Sukces pokazujemy tylko po potwierdzeniu backendu.
- Uprawnienia egzekwuje baza (RLS + RPC), UI tylko je odzwierciedla.
- Na tagach i w QR jest wyłącznie nieprzezroczysty identyfikator aplikacji — zero danych medycznych, imion, haseł.
- Tylko fikcyjne dane pacjentów.

---

## 2. Wymagania obowiązkowe (kompletna lista — każda pozycja jest P0)

| # | Wymaganie | Jak realizujemy |
|---|---|---|
| 1 | Aplikacja mobilna działająca na Androidzie i iOS. | Flutter, jedna baza kodu, testy na fizycznych urządzeniach obu platform. |
| 2 | Logowanie użytkowników. | Supabase Auth (email + hasło), sesja w secure storage, auto-refresh tokenu. |
| 3 | Dwie role użytkowników: Nurse (pielęgniarka) i Doctor (lekarz). | Tabela `profiles.role` (enum `nurse`/`doctor`, opcjonalnie `admin`). |
| 4 | Pielęgniarka może zmieniać lokalizację pacjenta. | RPC `transfer_patient` sprawdza `role = 'nurse'`. |
| 5 | Lekarz może zmieniać status pacjenta. | RPC `set_patient_status` sprawdza `role = 'doctor'`. |
| 6 | Obie role mogą przeglądać dane pacjentów i historię przemieszczeń. | Polityki RLS `SELECT` dla `authenticated`. |
| 7 | Uprawnienia muszą być egzekwowane przez backend, a nie tylko interfejs. | Brak grantów `INSERT/UPDATE/DELETE` na tabelach dla `authenticated`; zapis tylko przez `SECURITY DEFINER` RPC z kontrolą roli. |
| 8 | Użytkownik nie może samodzielnie nadawać sobie uprawnień. | `profiles` bez polityki UPDATE dla roli; role nadaje seed SQL/Edge Function z service role. |
| 9 | Odczytywanie identyfikatorów pacjentów z tagów NFC NTAG213. | `nfc_manager`, rekord NDEF Text. |
| 10 | Skanowanie kodów QR. | `mobile_scanner`. |
| 11 | NFC i QR muszą identyfikować tego samego pacjenta. | Ten sam string `HPT-XXXXXXXX` w NDEF i w QR → ta sama funkcja `resolvePatient(code)`. |
| 12 | Obsługa błędnych i nieznanych identyfikatorów oraz anulowania skanowania. | Parser z walidacją formatu, osobne komunikaty: *nieprawidłowy format*, *nieznany pacjent*, *anulowano*. |
| 13 | Obsługa braku NFC i odmowy dostępu do kamery. | `NfcManager.isAvailable()` w runtime → fallback do QR; obsługa `permission denied` z przyciskiem „Otwórz ustawienia”. |
| 14 | Wyświetlanie danych pacjenta: imię, nazwisko, wiek, schorzenie, data przyjęcia. | Sekcja „Dane” w profilu i w bottom sheecie. |
| 15 | Wyświetlanie ostatniej zarejestrowanej lokalizacji pacjenta i czasu jej aktualizacji. | `current_location` + `location_updated_at`, format względny („12 min temu”) + absolutny. |
| 16 | Wyświetlanie statusu pacjenta: Admitted, In Treatment, Ready for Discharge, Discharged. | Enum `patient_status`, chip z kolorem + ikoną + tekstem. |
| 17 | Wybór oddziału docelowego i ręczne zatwierdzenie przeniesienia pacjenta. | Bottom sheet wyboru + ekran potwierdzenia. |
| 18 | Samo skanowanie NFC lub QR nie może zmieniać lokalizacji pacjenta. | Skan wywołuje tylko odczyt (`select`), zero zapisów lokalizacji. |
| 19 | Oddzielne przechowywanie statusu i lokalizacji pacjenta. | Dwie kolumny, dwa RPC, dwie tabele historii. |
| 20 | Zapisywanie pełnej historii przemieszczeń: poprzedni oddział, nowy oddział, data, godzina, użytkownik i unikalny identyfikator zdarzenia. | `location_history(event_id uuid, patient_id, from_location, to_location, created_at, updated_by)`. |
| 21 | Atomowy zapis nowej lokalizacji i zdarzenia w historii. | Jedna funkcja PL/pgSQL = jedna transakcja, `SELECT … FOR UPDATE`. |
| 22 | Brak możliwości edytowania i usuwania historii przez zwykłych użytkowników. | Brak grantów i polityk UPDATE/DELETE + trigger blokujący. |
| 23 | Lista wszystkich pacjentów wraz z ich lokalizacjami i statusami. | Ekran „Pacjenci”. |
| 24 | Wyszukiwanie pacjentów po imieniu, nazwisku lub identyfikatorze. | Wyszukiwanie lokalne (cache) + `ilike` / `pg_trgm` po stronie serwera. |
| 25 | Filtrowanie pacjentów po lokalizacji i statusie. | Chipy filtrów. |
| 26 | Synchronizacja w czasie rzeczywistym — zmiana na jednym urządzeniu pojawia się na drugim bez ręcznego odświeżania. | Supabase Realtime `postgres_changes` na `patients`, `location_history`, `status_history`. |
| 27 | Obsługa stanów ładowania, pustych wyników i błędów. | `AsyncValue` z Riverpod → skeleton / empty / error z akcją. |
| 28 | Obsługa braku internetu i wyświetlanie informacji o trybie offline. | `connectivity_plus` + status kanału realtime + ping; baner offline. |
| 29 | Możliwość przeglądania wcześniej zapisanych danych z cache, jeśli są dostępne, z oznaczeniem ich jako potencjalnie nieaktualnych. | Drift (SQLite) jako cache; etykieta „Dane z cache · synchronizacja 10:42”. Gdy brak cache → komunikat, że potrzebne jest połączenie. |
| 30 | Blokowanie aktualizacji danych bez internetu w wersji podstawowej. | Przyciski „Przenieś”/„Zmień status” wyłączone offline + wyjaśnienie. Żadnego cichego kolejkowania. |
| 31 | Potwierdzanie sukcesu operacji dopiero po odpowiedzi backendu. | Checkmark tylko po `200` z RPC; timeout = „nie wiadomo, czy zapisano → sprawdź” (bezpieczne dzięki idempotencji). |
| 32 | Zapobieganie zduplikowanym transferom przy wielokrotnym kliknięciu. | Blokada przycisku + `client_request_id` (UUID per intencja) z ograniczeniem `UNIQUE` → serwer zwraca to samo zdarzenie. |
| 33 | Obsługa konfliktów, gdy dwóch użytkowników próbuje jednocześnie przenieść pacjenta. | Optymistyczna współbieżność: `expected_version`; nieaktualna wersja → błąd `PT409` → ekran konfliktu + odświeżenie. |
| 34 | Chmurowa baza danych i uwierzytelnianie. | Supabase (Postgres + Auth). |
| 35 | Walidacja identyfikatorów, oddziałów i statusów po stronie backendu. | `CHECK` na formacie kodu, FK do `locations`, enum statusów, walidacja w RPC. |
| 36 | Wykorzystanie czasu serwera oraz tożsamości zalogowanego użytkownika. | `now()` i `auth.uid()` w RPC; klient nie wysyła ani czasu, ani id użytkownika. |
| 37 | Przechowywanie wyłącznie fikcyjnych danych pacjentów. | Seed z wygenerowanymi danymi; nota w README i w aplikacji („SIMULATION ONLY”). |
| 38 | Zakaz zapisywania danych medycznych bezpośrednio na tagach NFC i w kodach QR — tylko identyfikator pacjenta, inny niż sprzętowy UID taga. | NDEF Text = `HPT-XXXXXXXX`; UID taga ignorowany. |
| 39 | Testy na fizycznych urządzeniach Android i iOS, w tym odczytu NFC. | Macierz testów z modelami i wersjami OS (sekcja 17). |
| 40 | Praca zespołowa 3–4 osób z wykorzystaniem Git. | GitHub, branch per feature, PR + review, CI z `flutter analyze` i testami. |
| 41 | Dokumentacja architektury, konfiguracji backendu, uprawnień, testów, obsługi offline i konfliktów oraz wkładu członków zespołu. | Folder `docs/` (sekcja 18). |
| 42 | Przygotowanie przykładowych pacjentów, kont testowych, tagów NFC i kodów QR. | `supabase/seed.sql` + `tools/generate_tags` (CSV + PDF z QR). |
| 43 | Udokumentowanie wyników testów, wersji systemów operacyjnych i znanych ograniczeń. | `docs/TESTING.md` z tabelą wyników. |
| 44 | Końcowa demonstracja działania aplikacji, obejmująca testy uprawnień, synchronizacji, offline i konfliktów. | Scenariusz demo (sekcja 16). |
| 45 | Każdy członek zespołu musi umieć wyjaśnić działanie systemu. | Rotacja code review + próbne „przesłuchanie” w tygodniu 7. |

### 2.1 Dodatkowe szczegóły z oficjalnej specyfikacji (PDF), które też są obowiązkowe

- Tag NFC przyklejony do symulowanej opaski lub teczki.
- Odczyt NDEF identyfikatora na **obu** platformach do końca tygodnia 1.
- Sprawdzenie dostępności NFC w runtime i oferowanie QR, gdy NFC niedostępne.
- Nieuwierzytelniony dostęp musi być odrzucony. **Posiadanie identyfikatora pacjenta nie daje dostępu** — bez zalogowania nikt nie odczyta rekordu.
- Konta testowe i role nadawane przez zaufany proces (seed).
- Dla każdego transferu: unikalny `eventId`, `patientId`, poprzednia lokalizacja, cel, **czas serwera**, **uwierzytelniony aktor**.
- Gdy brak cache offline → wyjaśnienie, że wymagane jest połączenie.
- Udokumentowana polityka konfliktów (np. odrzucanie nieaktualnych zmian i prośba o odświeżenie) z zachowaniem spójności rekordu i historii.
- Reprodukowalne instrukcje: schemat, reguły dostępu, dane syntetyczne; **bez prywatnych kluczy w repo**.
- Demo synchronizacji: **jeden iOS + jeden Android**.
- Raport: architektura, format identyfikatora, uprawnienia, współbieżność i offline, wyzwania, wkład indywidualny.
- Czysta instalacja z dokumentacji w tygodniu 8 (ktoś, kto nie stawiał backendu, stawia go od zera z README).

### 2.2 Macierz uprawnień (egzekwowana w bazie)

| Operacja | Nurse | Doctor | Admin (opcjonalny) | Anon |
|---|---|---|---|---|
| Odczyt danych pacjenta i historii | ✅ | ✅ | ✅ | ❌ |
| Zmiana lokalizacji pacjenta | ✅ | ❌ | ❌* | ❌ |
| Zmiana statusu pacjenta | ❌ | ✅ | ❌* | ❌ |
| Nadawanie ról | ❌ | ❌ | ✅ (Edge Function) | ❌ |
| Edycja/usuwanie historii | ❌ | ❌ | ❌ | ❌ |
| Notatki medyczne (rozszerzenie) | dodaje | dodaje | odczyt | ❌ |
| Programowanie tagów (rozszerzenie) | ✅ | ❌ | ✅ | ❌ |
| Tryb demo / reset danych (rozszerzenie) | ❌ | ❌ | ✅ | ❌ |

\* Admin zarządza ludźmi, nie pacjentami — trzyma się macierzy ze specyfikacji.

---

## 3. Wybrany stack technologiczny

| Warstwa | Technologia | Po co |
|---|---|---|
| Frontend | **Flutter + Dart** | Jedna baza kodu iOS/Android. |
| Backend | **Supabase** | Auth, Postgres, Realtime, Edge Functions w jednym. |
| Baza danych | **PostgreSQL** | Transakcje, constrainty, RLS. |
| Autoryzacja | **Supabase Auth** | JWT, `auth.uid()` w SQL. |
| Bezpieczeństwo | **Row Level Security (RLS)** | Uprawnienia po stronie bazy. |
| Operacje atomowe | **PostgreSQL RPC + transakcje** | `transfer_patient`, `set_patient_status`. |
| Synchronizacja | **Supabase Realtime** | Zmiany na żywo na drugim urządzeniu. |
| NFC | **nfc_manager** (lub odpowiednia biblioteka) | Odczyt/zapis NDEF NTAG213. |
| QR | **mobile_scanner** | QR + dodatkowe formaty (Code128, DataMatrix, PDF417…). |
| Lokalne dane | **SQLite / Drift** | Cache offline, kolejka operacji (rozszerzenie). |
| Stan | **Riverpod** | Providery, `AsyncValue`, strumienie realtime. |
| Repozytorium | **GitHub** | PR, review, Actions (CI). |
| Dodatkowo | `go_router`, `connectivity_plus`, `flutter_animate`, `fl_chart`, `qr_flutter`, `pdf` + `printing`, `uuid`, `intl`, `lucide_icons`, `flutter_secure_storage`, `permission_handler`, `app_settings` | Nawigacja, sieć, animacje, wykresy, generowanie kart, ikony, uprawnienia. |

---

## 4. Architektura

```
┌─────────────────────────────── FLUTTER APP ────────────────────────────────┐
│  UI (screens, widgets, animations)                                          │
│    Dashboard · Pacjenci · Skanuj · Historia · Profil · Mapa · Ward monitor │
│        ▲ watch                                                              │
│  Riverpod providers / controllers (AsyncValue, StreamProvider)              │
│        ▲                                                                    │
│  Repozytoria (PatientRepo, TransferRepo, HistoryRepo, MapRepo, ScanRepo)    │
│     │                │                         │                            │
│  Supabase client   Drift cache (SQLite)     NFC / QR adaptery               │
│  (REST + RPC +     patients, locations,     nfc_manager, mobile_scanner     │
│   Realtime WS)     history, outbox*                                         │
└─────┬───────────────────────────────────────────────────────────────────────┘
      │ HTTPS (JWT)                       ▲ WebSocket (postgres_changes)
┌─────▼───────────────────────────── SUPABASE ───────────────────────────────┐
│  Auth (users)  ──►  profiles(role)                                          │
│  PostgREST: SELECT (RLS)       RPC: transfer_patient / set_patient_status   │
│  Postgres: patients · locations · location_history · status_history ·       │
│            clinical_notes* · scan_events* · transfer_requests*              │
│  Realtime publication · Edge Functions: admin-set-role*, demo-reset*        │
└─────────────────────────────────────────────────────────────────────────────┘
   * = rozszerzenia
```

### 4.1 Struktura repozytorium

```
hospital-tracker/
├─ app/                                  # Flutter
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ app/            router.dart, theme/ (tokens, colors, typography, motion)
│  │  ├─ core/           supabase.dart, connectivity.dart, errors.dart (mapowanie PTxxx),
│  │  │                  patient_code.dart (parser/walidator), haptics.dart, clock.dart
│  │  ├─ data/           drift/ (db.dart, tables.dart), repositories/, dto/
│  │  └─ features/
│  │     ├─ auth/            login, sesja, rola
│  │     ├─ dashboard/       KPI, wykresy, feed, szybkie akcje
│  │     ├─ patients/        lista, wyszukiwarka, filtry
│  │     ├─ patient_profile/ dane, status, lokalizacja, timeline, mini-mapa
│  │     ├─ scan/            NFC, QR, fallback, quick-summary sheet
│  │     ├─ transfer/        wybór oddziału, potwierdzenie, konflikt
│  │     ├─ status/          zmiana statusu (Doctor), rejestr zmian
│  │     ├─ history/         historia globalna, historia oddziału, timeline dnia
│  │     ├─ map/             mapa 2D/3D, heatmapa, ścieżki, panel oddziału
│  │     ├─ analytics/       sankey, godziny szczytu, teraz vs rano, NFC/QR, wąskie gardła
│  │     ├─ ward_monitor/    widok monitora oddziału (tablet/landscape)
│  │     ├─ notes/           notatki medyczne
│  │     ├─ notifications/   powiadomienia in-app
│  │     ├─ admin/           konta, role, programowanie tagów, karty pacjentów
│  │     ├─ offline_queue/   kolejka synchronizacji (tryb rozszerzony)
│  │     └─ demo/            tryb demonstracyjny / showcase
│  ├─ test/                 unit + widget
│  └─ integration_test/     scenariusze na urządzeniach
├─ supabase/
│  ├─ migrations/  0001_schema.sql 0002_rls.sql 0003_rpc.sql 0004_realtime.sql
│  │               0005_analytics.sql 0006_extensions.sql
│  ├─ seed.sql
│  ├─ tests/       *.sql (pgTAP: RLS, RPC, konflikty, idempotencja)
│  └─ functions/   admin-set-role/  demo-reset/
├─ tools/
│  ├─ generate_tags/       CSV identyfikatorów + PDF z QR do druku
│  └─ concurrency_test/    skrypt odpalający 2 równoległe transfery
└─ docs/  ARCHITECTURE.md BACKEND.md PERMISSIONS.md ID_FORMAT.md
          OFFLINE_AND_CONFLICTS.md TESTING.md DEMO_SCRIPT.md CONTRIBUTIONS.md
```

---

## 5. Model danych i backend (SQL gotowy do migracji)

### 5.1 Schemat

```sql
-- 0001_schema.sql
create extension if not exists pg_trgm;

create type user_role      as enum ('nurse','doctor','admin');
create type patient_status as enum ('admitted','in_treatment','ready_for_discharge','discharged');
create type location_kind  as enum ('emergency','ward','diagnostic','lab','surgery','icu','other');

create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null,
  role       user_role not null,
  initials   text generated always as (
               upper(left(split_part(full_name,' ',1),1) || left(split_part(full_name,' ',2),1))) stored,
  home_location text,                              -- oddział macierzysty (transfery z akceptacją)
  shift_label   text                               -- "Zmiana dzienna 7–19" (nagłówek dashboardu)
);

create table locations (
  id            text primary key,                  -- 'ER','RAD','LAB','INT',...
  display_name  text not null,
  kind          location_kind not null,
  floor         smallint not null,                 -- 0 = parter
  beds          smallint not null default 0,
  map_x numeric, map_y numeric, map_w numeric, map_h numeric   -- geometria dla mapy
);

create table patients (
  id                  uuid primary key default gen_random_uuid(),
  patient_code        text not null unique
                      check (patient_code ~ '^HPT-[0-9A-HJKMNP-TV-Z]{8}$'),
  first_name          text not null,
  last_name           text not null,
  age                 smallint not null check (age between 0 and 120),
  condition           text not null,
  admission_date      timestamptz not null,
  current_location    text not null references locations(id),
  status              patient_status not null default 'admitted',
  last_updated        timestamptz not null default now(),
  location_updated_at timestamptz not null default now(),
  version             integer not null default 1
);
create index patients_name_trgm on patients using gin ((first_name||' '||last_name) gin_trgm_ops);

create table location_history (
  event_id          uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references patients(id),
  from_location     text references locations(id),     -- null = przyjęcie
  to_location       text not null references locations(id),
  created_at        timestamptz not null default now(),-- CZAS SERWERA
  updated_by        uuid not null references profiles(id),
  client_request_id uuid unique                         -- idempotencja
);
create index on location_history (patient_id, created_at);
create index on location_history (to_location, created_at);

create table status_history (                          -- rejestr zmian statusów
  event_id          uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references patients(id),
  from_status       patient_status,
  to_status         patient_status not null,
  reason            text,                              -- opcjonalne uzasadnienie
  created_at        timestamptz not null default now(),
  changed_by        uuid not null references profiles(id),
  client_request_id uuid unique
);
```

### 5.2 RLS i granty — tu się wygrywa albo oblewa test „bypass UI”

```sql
-- 0002_rls.sql
alter table profiles          enable row level security;
alter table locations         enable row level security;
alter table patients          enable row level security;
alter table location_history  enable row level security;
alter table status_history    enable row level security;

-- tylko zalogowani czytają
create policy read_profiles  on profiles         for select to authenticated using (true);
create policy read_locations on locations        for select to authenticated using (true);
create policy read_patients  on patients         for select to authenticated using (true);
create policy read_lhist     on location_history for select to authenticated using (true);
create policy read_shist     on status_history   for select to authenticated using (true);

-- ZERO zapisów bezpośrednich. Nie ma polityk insert/update/delete,
-- a dodatkowo odbieramy granty, żeby PATCH przez REST dawał twarde "permission denied".
revoke insert, update, delete on profiles, locations, patients,
       location_history, status_history from anon, authenticated;
revoke all on all tables in schema public from anon;

-- historia jest append-only nawet dla kogoś z kluczem service_role "przez przypadek"
create function forbid_history_mutation() returns trigger language plpgsql as $$
begin raise exception 'History is append-only' using errcode = 'PT403'; end $$;
create trigger lhist_no_mutation before update or delete on location_history
  for each row execute function forbid_history_mutation();
create trigger shist_no_mutation before update or delete on status_history
  for each row execute function forbid_history_mutation();
```

### 5.3 RPC: atomowy transfer z kontrolą konfliktu i idempotencją

```sql
-- 0003_rpc.sql
-- kody błędów (mapowane w aplikacji na komunikaty):
-- PT401 brak sesji | PT403 brak uprawnień | PT404 nieznany pacjent
-- PT409 konflikt (nieaktualna wersja) | PT422 zły oddział / ten sam oddział / zły status
create or replace function transfer_patient(
  p_patient_id uuid, p_to text, p_expected_version int, p_request_id uuid)
returns location_history
language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_pat patients; v_evt location_history;
begin
  if auth.uid() is null then raise exception 'UNAUTHENTICATED' using errcode='PT401'; end if;
  select role into v_role from profiles where id = auth.uid();
  if v_role is distinct from 'nurse' then raise exception 'FORBIDDEN' using errcode='PT403'; end if;
  if not exists (select 1 from locations where id = p_to) then
    raise exception 'INVALID_LOCATION' using errcode='PT422'; end if;

  select * into v_pat from patients where id = p_patient_id for update;   -- blokada wiersza
  if not found then raise exception 'UNKNOWN_PATIENT' using errcode='PT404'; end if;

  -- idempotencja: ten sam request (podwójny klik, retry po timeoucie) = to samo zdarzenie
  select * into v_evt from location_history where client_request_id = p_request_id;
  if found then return v_evt; end if;

  if v_pat.version <> p_expected_version then
    raise exception 'STALE_VERSION' using errcode='PT409',
      detail = json_build_object('current_location', v_pat.current_location,
                                 'version', v_pat.version)::text;
  end if;
  if v_pat.current_location = p_to then raise exception 'SAME_LOCATION' using errcode='PT422'; end if;

  update patients
     set current_location = p_to, location_updated_at = now(),
         last_updated = now(), version = version + 1
   where id = p_patient_id;

  insert into location_history(patient_id, from_location, to_location, updated_by, client_request_id)
  values (p_patient_id, v_pat.current_location, p_to, auth.uid(), p_request_id)
  returning * into v_evt;
  return v_evt;                                     -- obie zmiany albo żadna (jedna transakcja)
end $$;

create or replace function set_patient_status(
  p_patient_id uuid, p_status patient_status, p_expected_version int,
  p_request_id uuid, p_reason text default null)
returns status_history
language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_pat patients; v_evt status_history;
begin
  if auth.uid() is null then raise exception 'UNAUTHENTICATED' using errcode='PT401'; end if;
  select role into v_role from profiles where id = auth.uid();
  if v_role is distinct from 'doctor' then raise exception 'FORBIDDEN' using errcode='PT403'; end if;

  select * into v_pat from patients where id = p_patient_id for update;
  if not found then raise exception 'UNKNOWN_PATIENT' using errcode='PT404'; end if;
  select * into v_evt from status_history where client_request_id = p_request_id;
  if found then return v_evt; end if;
  if v_pat.version <> p_expected_version then raise exception 'STALE_VERSION' using errcode='PT409'; end if;
  if v_pat.status = p_status then raise exception 'SAME_STATUS' using errcode='PT422'; end if;

  update patients set status = p_status, last_updated = now(), version = version + 1
   where id = p_patient_id;
  insert into status_history(patient_id, from_status, to_status, reason, changed_by, client_request_id)
  values (p_patient_id, v_pat.status, p_status, p_reason, auth.uid(), p_request_id)
  returning * into v_evt;
  return v_evt;
end $$;

revoke all on function transfer_patient, set_patient_status from public, anon;
grant execute on function transfer_patient, set_patient_status to authenticated;
```

> **Decyzja projektowa (do raportu):** wersja (`version`) jest wspólna dla lokalizacji i statusu. Konsekwencja: jeśli lekarz zmieni status w tej samej sekundzie, w której pielęgniarka zatwierdza transfer, pielęgniarka dostanie konflikt i musi odświeżyć. To celowo konserwatywne — wolimy fałszywy konflikt niż decyzję podjętą na nieaktualnym ekranie. Alternatywa: osobne `location_version` i `status_version`. Wybierzcie świadomie i opiszcie.

### 5.4 Realtime

```sql
-- 0004_realtime.sql
alter publication supabase_realtime add table patients, location_history, status_history;
```

Klient subskrybuje `postgres_changes` (RLS działa także dla realtime). **Po każdym reconnect: pełny refetch** listy pacjentów i ostatnich zdarzeń, bo Realtime nie odtwarza zaległych zdarzeń.

### 5.5 Format identyfikatora (ID_FORMAT.md)

| Element | Wartość |
|---|---|
| Format | `HPT-` + 8 znaków Crockford Base32 (bez I, L, O, U), np. `HPT-7K3M9QX2` |
| Regex | `^HPT-[0-9A-HJKMNP-TV-Z]{8}$` |
| NFC | NTAG213 (144 B pamięci użytkownika), jeden rekord **NDEF Text**, język `en`, payload = identyfikator |
| QR | Dokładnie ten sam string, bez URL, bez prefiksów, ECC poziom M |
| Zakazane | imiona, schorzenia, daty, hasła, tokeny, URL z danymi; **UID chipu nie jest identyfikatorem** |
| Walidacja | klient: regex przed zapytaniem (komunikat „nieprawidłowy format”); serwer: `CHECK` + lookup (komunikat „nieznany pacjent”) |
| Bezpieczeństwo | znajomość kodu nie daje dostępu — bez sesji RLS nic nie zwraca |

### 5.6 Seed (fragment)

```sql
insert into locations(id, display_name, kind, floor, beds, map_x, map_y, map_w, map_h) values
 ('ER' ,'SOR',                    'emergency', 0, 24,  0, 0, 14, 10),
 ('ADM','Izba Przyjęć',           'other',     0, 10, 14, 0, 10, 10),
 ('RAD','Radiologia',             'diagnostic',0, 14, 24, 0, 20, 10),
 ('LAB','Laboratorium',           'lab',       0, 12,  0,12, 22, 10),
 ('INT','Oddział Wewnętrzny',     'ward',      1, 32,  0, 0, 22, 12),
 ('CAR','Kardiologia',            'ward',      1, 20, 22, 0, 22, 12),
 ('SUR','Chirurgia',              'ward',      1, 24,  0,12, 22, 10),
 ('OR' ,'Blok Operacyjny',        'surgery',   1,  8, 22,12, 22, 10),
 ('ICU','OIOM',                   'icu',       2,  8,  0, 0, 14, 10),
 ('NEU','Neurologia',             'ward',      2, 20, 14, 0, 30, 10),
 ('ORT','Ortopedia',              'ward',      2, 22,  0,12, 22, 10),
 ('REH','Rehabilitacja',          'ward',      2, 16, 22,12, 22, 10);
-- + 20–40 fikcyjnych pacjentów, konta: nurse1/nurse2/doctor1/doctor2/admin (hasła tylko w lokalnym .env, NIE w repo)
-- + zdarzenia przyjęcia w location_history (from_location = null), żeby timeline i analityka miały dane
```

---

## 6. Offline, cache i konflikty (OFFLINE_AND_CONFLICTS.md)

### 6.1 Wersja podstawowa (P0)

| Sytuacja | Zachowanie |
|---|---|
| Brak sieci, jest cache | Dane z Drift + baner „Offline” + etykieta „Dane z cache · ostatnia synchronizacja 10:42 · mogą być nieaktualne”. |
| Brak sieci, brak cache dla rekordu | Pusty stan: „Ten pacjent nie był jeszcze pobrany na tym urządzeniu. Połącz się z internetem.” |
| Brak sieci, próba transferu/statusu | Przycisk wyłączony + tooltip „Zmiany wymagają połączenia”. Nic nie trafia do kolejki. |
| Timeout RPC | Komunikat „Nie wiemy, czy zapis się udał” → przycisk „Sprawdź” ponawia **z tym samym `client_request_id`** → serwer zwraca istniejące zdarzenie albo wykonuje transfer raz. |
| Podwójny klik | Przycisk zablokowany od pierwszego tapu + ten sam `client_request_id` → jedno zdarzenie. |
| Konflikt (`PT409`) | Ekran konfliktu: „Pacjent został w międzyczasie przeniesiony do Radiologii przez A. Nowak (10:41). Twoja zmiana nie została zapisana.” → „Odśwież i wybierz ponownie”. Nigdy automatycznego ponowienia. |
| Powrót sieci | Reconnect realtime → pełny refetch → zdjęcie banera, etykiety cache znikają. |

### 6.2 Rozszerzenie: pełny tryb offline z synchronizacją (P3, za flagą, domyślnie OFF)

- Tabela Drift `outbox(id, op_type, payload, client_request_id, expected_version, created_at, state)`.
- Każda operacja offline jest **jawnie** widoczna: znaczek „Oczekuje na synchronizację” na karcie pacjenta + ekran „Kolejka synchronizacji” z listą, czasem i możliwością anulowania.
- Po odzyskaniu sieci: wysyłka sekwencyjna, w kolejności utworzenia, z tym samym `client_request_id` (bezpieczne retry).
- `PT409` z kolejki → operacja trafia do „Konflikty do rozwiązania”, **nie nadpisuje** danych serwera; użytkownik decyduje: odrzuć / ponów na aktualnej wersji.
- Automatyczne odświeżenie danych po odzyskaniu połączenia **bez nadpisywania nierozwiązanych konfliktów**.
- Na demo core flaga jest wyłączona (spełniamy „do not silently queue”), potem pokazujemy rozszerzenie osobno.

---

## 7. Design system i UI/UX (kompletnie, z Twojej listy)

**Kierunek:** premium medical SaaS — nowoczesny, minimalistyczny interfejs szpitalny, inspirowany estetyką Apple Health, Linear i profesjonalnych dashboardów medycznych. Bez zabawkowych elementów, przesadzonych gradientów i zbędnych animacji.

### 7.1 Design system i ogólny wygląd
- Minimalistyczny, profesjonalny interfejs z dużą ilością przestrzeni między elementami.
- Jasne tło w odcieniach bieli i bardzo delikatnej szarości.
- Główny kolor interfejsu: medyczny niebieski lub turkusowy.
- Subtelne gradienty wyłącznie w wybranych elementach, np. nagłówkach dashboardu.
- Zaokrąglone karty z delikatnymi obramowaniami zamiast ciężkich cieni.
- Spójny system odstępów, promieni zaokrągleń i rozmiarów komponentów.
- Typografia Inter lub SF Pro z wyraźną hierarchią informacji.
- Ikony w jednym stylu, najlepiej Lucide lub podobne minimalistyczne ikony.
- Kolory statusów pacjentów: niebieski — przyjęty, fioletowy — w trakcie leczenia, zielony — gotowy do wypisu, szary — wypisany.
- Statusy prezentowane zarówno kolorem, jak i tekstem oraz ikoną.
- Duże, czytelne przyciski odpowiednie do obsługi jedną ręką.
- Spójne animacje przejść i interakcji we wszystkich ekranach.

**Tokeny (propozycja, `app/theme/tokens.dart`):**

| Token | Wartość |
|---|---|
| `bg` / `surface` / `surface2` | `#FAFBFC` / `#FFFFFF` / `#F3F5F8` |
| `border` | `#E4E8EE` (1 px) |
| `primary` (medical teal) | `#0E9FA6` · hover `#0B858B` |
| `text` / `textMuted` | `#0F1720` / `#5B6675` |
| Status Admitted | `#2F6FEB` + ikona `log-in` |
| Status In Treatment | `#7C4DDB` + ikona `activity` |
| Status Ready for Discharge | `#14A35B` + ikona `check-circle` |
| Status Discharged | `#8A94A3` + ikona `log-out` |
| Heat: niskie / średnie / wysokie | `#22B573` / `#F29A2E` / `#E5484D` (+ wzór/etykieta, nie tylko kolor) |
| Odstępy | 4 · 8 · 12 · 16 · 24 · 32 · 48 |
| Promienie | 8 (chip) · 12 (input) · 16 (karta) · 24 (bottom sheet) |
| Motion | `fast 120ms` · `base 220ms` · `slow 380ms`, krzywa `easeOutCubic`; sprężyna dla sheetów |
| Touch target | min. 48×48 dp, główne akcje 56 dp |

### 7.2 Dashboard i ekran główny
- Powitalny nagłówek z imieniem zalogowanego pracownika, jego rolą i aktualną zmianą, jeśli taka informacja jest dostępna.
- Karty KPI z liczbą wszystkich pacjentów, pacjentów w leczeniu, gotowych do wypisu i dzisiejszych transferów.
- Animowane liczniki wartości podczas otwierania dashboardu.
- Miniwykresy trendów wewnątrz kart statystyk.
- Interaktywny wykres liczby pacjentów na poszczególnych oddziałach.
- Sekcja ostatnich transferów przedstawiona jako kompaktowy activity feed.
- Sekcja szybkich działań: skanowanie NFC, skanowanie QR, wyszukiwanie pacjenta.
- Karty najczęściej używanych oddziałów.
- Delikatna animacja pojawiania się kart przy pierwszym załadowaniu ekranu.
- Aktualizowanie statystyk na żywo bez przeładowywania całego dashboardu.
- Inspiracja stylistyczna dashboardu: Apple Health (karty i mikrowykresy), Linear (gęstość informacji, typografia, subtelne obramowania), profesjonalne dashboardy medyczne (czytelność statusów).

### 7.3 Lista pacjentów i profil pacjenta
- Eleganckie karty pacjentów z imieniem i nazwiskiem, identyfikatorem, lokalizacją i statusem.
- Kolorowy, dyskretny pasek lub znacznik statusu na każdej karcie.
- Awatary z inicjałami zamiast losowych zdjęć pacjentów.
- Płynne rozwijanie szczegółów pacjenta.
- Animowane przejście z listy do szczegółowego profilu.
- Przyklejony pasek wyszukiwania podczas przewijania listy.
- Filtry w formie poziomych, przewijanych chipów.
- Subtelne animacje podczas zmiany filtrów i sortowania.
- Sekcja najważniejszych informacji o pacjencie na górze profilu.
- Wyraźnie oddzielone dane medyczne, lokalizacja, status i historia.
- Oś czasu przedstawiająca historię pobytu oraz transferów między oddziałami.
- Ikony oddziałów dopasowane do typu jednostki: SOR, radiologia, laboratorium itd.
- Animowane rozwijanie poszczególnych zdarzeń na osi czasu.
- Widoczna data i godzina ostatniej aktualizacji informacji o lokalizacji.

### 7.4 Skaner NFC i QR — najważniejszy wizualnie ekran
- Duży, centralny przycisk skanowania dostępny z dolnej nawigacji.
- Dedykowany ekran skanowania z minimalistycznym interfejsem.
- Animowane pierścienie rozchodzące się wokół symbolu NFC.
- Subtelna animacja pulsowania podczas oczekiwania na tag.
- Delikatne sprzężenie haptyczne po wykryciu tagu.
- Efekt rozświetlenia obszaru skanowania po prawidłowym odczycie.
- Płynne przejście od animacji skanowania do karty zidentyfikowanego pacjenta.
- Skaner QR z narożnikami wyznaczającymi obszar skanowania.
- Animowana linia skanowania kodu QR.
- Automatyczne przejście do skanera QR, gdy NFC nie jest obsługiwane, po poinformowaniu użytkownika.
- Estetyczne komunikaty o błędnych tagach, nieznanych identyfikatorach i problemach z uprawnieniami.
- Wyraźne rozróżnienie między odczytem identyfikatora a zatwierdzeniem transferu.

> **Realizm platformowy:** Android — pełny własny UI w trakcie sesji (reader mode, foreground). iOS — pierścienie i puls na ekranie „Przyłóż telefon do opaski” → wywołanie sesji (systemowy arkusz) → po odczycie Wasze rozświetlenie + haptyka + przejście do karty pacjenta. Komunikat systemowego arkusza ustawiacie przez `alertMessage`.

### 7.5 Transfer pacjenta — mikrointerakcje
- Wybór oddziału docelowego za pomocą eleganckiej listy lub dolnego panelu.
- Wyszukiwarka oddziałów z podpowiedziami.
- Wizualizacja transferu: Oddział A → Oddział B.
- Subtelna animacja przesunięcia wskaźnika między oddziałami.
- Ekran potwierdzenia transferu przedstawiający poprzednią i nową lokalizację.
- Przycisk zatwierdzenia z animowanym stanem ładowania.
- Zablokowanie ponownego kliknięcia podczas zapisu.
- Animacja sukcesu, np. rysujący się checkmark, dopiero po potwierdzeniu transakcji przez backend.
- Krótki komunikat potwierdzający wykonany transfer.
- Automatyczna aktualizacja profilu pacjenta i historii przemieszczeń.
- Czytelny ekran konfliktu, jeśli inny pracownik wcześniej zmienił lokalizację pacjenta.

### 7.6 Realtime i animacje danych
- Płynna aktualizacja kart pacjentów po zmianach z Supabase Realtime.
- Krótkie podświetlenie rekordu, który właśnie został zaktualizowany.
- Animowane zmiany liczników na dashboardzie.
- Delikatne przejścia przy zmianie statusu pacjenta.
- Automatyczne dodawanie nowych zdarzeń do timeline'u.
- Mały wskaźnik aktywnego połączenia z serwerem.
- Wyraźne powiadomienie o utracie synchronizacji.
- Aktualizacje bez nagłego przeskakiwania list i utraty pozycji przewijania.

> **Technicznie:** listy z kluczami `ValueKey(patient.id)` + `AnimatedList`/`SliverAnimatedList` dla wstawień; zmiana pola = `TweenAnimationBuilder` koloru tła (flash 900 ms); zachowanie scrolla przez stabilne klucze i brak przebudowy całej listy.

### 7.7 Offline, loading i obsługa błędów
- Skeleton loading zamiast pustych ekranów podczas pobierania danych.
- Delikatny shimmer na szkieletach kart.
- Animowane, minimalistyczne wskaźniki ładowania.
- Estetyczny baner informujący o utracie połączenia internetowego.
- Znacznik danych z cache oraz czas ich ostatniej synchronizacji.
- Wizualne oznaczenie operacji oczekujących na synchronizację w opcjonalnym pełnym trybie offline.
- Czytelny widok kolejki synchronizacji offline.
- Komunikaty błędów zawierające konkretne informacje i możliwe działania.
- Puste stany z minimalistycznymi ilustracjami i krótkim wyjaśnieniem.
- Automatyczne odświeżenie danych po odzyskaniu połączenia, bez nadpisywania nierozwiązanych konfliktów.

**Katalog komunikatów (fragment):**

| Kod / sytuacja | Tytuł | Treść | Akcja |
|---|---|---|---|
| format | Nieprawidłowy identyfikator | Ten tag nie zawiera identyfikatora pacjenta HPT. | Skanuj ponownie |
| PT404 | Nieznany pacjent | Identyfikator HPT-7K3M9QX2 nie istnieje w systemie. | Wyszukaj ręcznie |
| cancel | Skanowanie anulowane | — (cichy powrót) | — |
| no NFC | NFC niedostępne | To urządzenie nie obsługuje NFC lub jest wyłączone. Przełączam na QR. | Użyj QR / Ustawienia |
| camera denied | Brak dostępu do kamery | Bez kamery nie zeskanujemy kodu QR. | Otwórz ustawienia |
| PT403 | Brak uprawnień | Zmianę lokalizacji może zatwierdzić tylko pielęgniarka. | OK |
| PT409 | Pacjent został już przeniesiony | {kto} przeniósł pacjenta do {gdzie} o {kiedy}. | Odśwież |
| offline | Jesteś offline | Przeglądasz dane z {czas}. Zmiany wymagają połączenia. | — |
| timeout | Brak potwierdzenia | Nie wiemy, czy zapis się udał. Sprawdzimy bez ryzyka duplikatu. | Sprawdź |

### 7.8 Nawigacja, gesty i ergonomia
- Dolny pasek nawigacji: Dashboard, Pacjenci, Skanuj, Historia, Profil.
- Wyróżniony centralny przycisk skanowania.
- Animowany wskaźnik aktywnej zakładki.
- Naturalne przejścia między ekranami zgodne z zachowaniem platformy.
- Obsługa gestu cofania i natywnych gestów iOS oraz Androida.
- Pull-to-refresh z subtelną animacją.
- Bottom sheets zamiast osobnych ekranów dla krótkich operacji.
- Swipe actions dla bezpiecznych skrótów, bez wykonywania transferów bez potwierdzenia.
- Zachowywanie pozycji przewijania przy powrocie do listy.
- Powiększone strefy dotyku dla najczęściej używanych akcji.
- Dostępność: czytelny kontrast, skalowanie tekstu i obsługa czytników ekranu.

> Mapa szpitala dostępna z Dashboardu (karta „Mapa”) i z profilu pacjenta (mini-mapa) — nie wciskamy szóstej zakładki do dolnego paska.

### 7.9 Dodatkowe efekty premium
- Staggered animations — elementy pojawiają się z niewielkim opóźnieniem jeden po drugim.
- Shared element transitions — płynne przejście wybranego elementu między ekranami.
- Subtelne haptics dla potwierdzeń, błędów i odczytów NFC.
- Animacje wykresów przy pierwszym pojawieniu się danych.
- Count-up animations dla statystyk.
- Animated status indicators — łagodne przejścia między kolorami statusów.
- Micro-scale animations — lekkie zmniejszenie przycisku podczas naciśnięcia.
- Płynne zmiany wysokości kart i paneli.
- Animowane wykresy przepływu pacjentów między oddziałami.
- Redukowanie lub wyłączanie animacji zgodnie z systemowymi ustawieniami dostępności.
- Wersja „glass / premium” dla najważniejszych kart — delikatny nowoczesny styl wizualny dla dashboardu, ale nadal profesjonalny (blur tła tylko pod nagłówkiem dashboardu i panelem mapy; `BackdropFilter` jest kosztowny — max 1–2 na ekranie).

### 7.10 Ekrany, które warto dopracować najbardziej
1. **Dashboard szpitala** — karty KPI, statystyki oddziałów, ostatnie transfery i elegancka nawigacja.
2. **Profil pacjenta** — najważniejsze dane, status, lokalizacja, timeline, transfery i notatki.
3. **Skaner NFC / QR** — centralny element aplikacji. Płynne animacje skanowania i szybki dostęp do pacjenta.
4. *(dodane)* **Mapa szpitala 2D/3D** — największy „wow” na prezentacji, ale dopiero po zaliczonym core.

---

## 8. Mapa szpitala, wizualizacje i analityka (kompletnie, z Twojej listy)

### 8.1 Lista funkcji

| # | Funkcja | Opis | Realizacja |
|---|---|---|---|
| M1 | **Interaktywna mapa szpitala 3D** | Widok budynku lub pięter szpitala w 3D, gdzie użytkownik może kliknąć oddział i zobaczyć, ilu pacjentów tam aktualnie przebywa. | Stos pięter: każde piętro to `Transform(Matrix4.identity()..setEntry(3,2,0.0012)..rotateX(-0.95)..rotateZ(yaw))`, oddziały to widgety z geometrią z tabeli `locations`. Gest obrotu/pinch. |
| M2 | **Mapa pięter i oddziałów z live statusami** | Każdy oddział może być podświetlony innym kolorem w zależności od liczby pacjentów, obłożenia albo rodzaju statusów. | Provider `occupancyByLocation` liczony z listy pacjentów (realtime) → kolor; tryb kolorowania: obłożenie / liczba / dominujący status. |
| M3 | **Widok „gdzie jest pacjent” na mapie** | Po wejściu w profil pacjenta aplikacja zaznacza jego ostatnią lokalizację bezpośrednio na mapie szpitala. | Pulsujący pin na środku oddziału `current_location`, kamera animuje się do piętra. |
| M4 | **Animowana ścieżka przemieszczania pacjenta** | Na osi czasu albo na mapie trasa pacjenta, np. SOR → Radiologia → Oddział Wewnętrzny → Laboratorium. | Polilinia przez środki oddziałów z `location_history`; `PathMetrics` + animowane `extractPath` (rysowanie się trasy), znacznik jadący po ścieżce; przejście między piętrami jako ikona windy ↑↓. |
| M5 | **Heatmapa obciążenia szpitala** | Oddziały bardziej obciążone mocniej zaznaczone kolorem: zielony → żółty → czerwony. | `Color.lerp` po progach (<60%, 60–85%, >85%), plus etykieta % (dostępność — nie tylko kolor). |
| M6 | **Podgląd oddziału po kliknięciu** | Panel z listą pacjentów, liczbą łóżek, liczbą wypisów i transferów. | `DraggableScrollableSheet` z danymi z providerów (pacjenci na oddziale, `beds`, wypisy dziś, transfery dziś in/out). |
| M7 | **Tryb 2D / 3D przełączany jednym kliknięciem** | Prosty plan pięter oraz efektowny widok 3D. | `TweenAnimationBuilder<double>` 0→1 interpoluje kąty macierzy; 2D = macierz identycznościowa. |
| M8 | **Mini-mapa w profilu pacjenta** | Mały podgląd: „ostatnia lokalizacja: Radiologia, piętro 1”. | Statyczny 2D plan jednego piętra (CustomPainter, 120 px) z podświetlonym oddziałem; tap → pełna mapa. |
| M9 | **Animowany dashboard obłożenia** | Osobny ekran: obłożenie wszystkich oddziałów, liczba pacjentów i ich ruch w czasie rzeczywistym. | Siatka kart oddziałów z paskami obłożenia + mini-mapa z animowanymi przejściami pacjentów. |
| M10 | **Wizualizacja przepływu pacjentów między oddziałami** | „Flow chart” / sankey-like view: skąd pacjenci najczęściej trafiają i dokąd są przenoszeni. | Agregacja `from→to` z `location_history`; własny `CustomPainter` (węzły + krzywe Béziera o grubości ∝ liczbie). |
| M11 | **Live activity feed** | Strumień zdarzeń: „Pacjent #P104 przeniesiony do Radiologii”, „Status zmieniony na Ready for Discharge”. | Merge strumieni realtime `location_history` + `status_history`, `AnimatedList`, awatar autora. |
| M12 | **Widok „na żywo” drugiego urządzenia** | Dwa telefony obok siebie: na jednym transfer, na drugim od razu zmiana. | To jest test akceptacyjny nr 2 — iOS + Android, ten sam projekt Supabase. |
| M13 | **Kolorowe stany oddziałów** | zielony — wolne miejsce / małe obłożenie; pomarańczowy — średnie obciążenie; czerwony — wysokie obłożenie. | Ten sam provider co heatmapa; legenda + ikona przy oddziale. |
| M14 | **Interaktywne karty oddziałów** | Karta rozwija się i pokazuje: liczbę pacjentów, ostatni transfer, średni czas pobytu. | `AnimatedSize` + dane z widoku `dept_stats`. |
| M15 | **Widok historii oddziału** | Historia ruchów na konkretnym oddziale (wejścia i wyjścia). | `location_history where from_location = X or to_location = X`. |
| M16 | **Animowany timeline dnia** | Wszystkie transfery wykonane danego dnia na osi czasu. | Oś 00–24 z kropkami zdarzeń (kolor wg celu), animowany „playhead”, scrub palcem. |
| M17 | **Wykres godzin największego ruchu** | O jakich godzinach najczęściej zachodzą przeniesienia. | 24 słupki z SQL `group by hour`. |
| M18 | **Tryb demonstracyjny / showcase** | Jednym kliknięciem gotowy scenariusz demo, gdzie „na żywo” odtwarzają się przykładowe transfery. | Patrz 9.16 — skrypt wywołuje te same RPC na koncie demo (uprawnienia nadal egzekwowane). |
| M19 | **Avatar / inicjały personelu przy zdarzeniach** | Kto wykonał operację — mała ikonka lekarza lub pielęgniarki. | `profiles.initials` + kolor roli (Nurse turkus, Doctor fiolet) + ikona `stethoscope`/`heart-pulse`. |
| M20 | **Panel szybkiego podsumowania pacjenta** | Po zeskanowaniu NFC wysuwa się elegancki bottom sheet z najważniejszymi informacjami bez wchodzenia od razu w profil. | `showModalBottomSheet` z hero do profilu; akcje zależne od roli. |
| M21 | **Widok „ward monitor”** | Ekran jak panel monitoringu oddziału — lista pacjentów, statusy, ostatnie ruchy, szybkie filtry. | Layout tablet/landscape, duża typografia, auto-odświeżanie realtime, opcjonalnie `wakelock`. |
| M22 | **Filtr wizualny po piętrach** | Parter / Piętro 1 / Piętro 2 — mapa tylko dla wybranego poziomu. | `SegmentedButton`; pozostałe piętra przyciemnione lub ukryte z animacją. |
| M23 | **Animacje przejść między oddziałami** | Przy transferze subtelna animacja przesunięcia pacjenta z jednego działu do drugiego. | Na mapie: kropka leci po łuku A→B (800 ms); w UI transferu: wskaźnik A → B. |
| M24 | **Wykrywanie „wąskich gardeł”** | Wizualne zaznaczanie oddziałów, do których trafia najwięcej pacjentów. | Reguła: przyjęcia z ostatnich 2 h / łóżka > próg **lub** obłożenie > 90% → ikonka ⚠ i obrys. |
| M25 | **Porównanie stanu „teraz” vs „rano”** | Jak zmieniło się obłożenie w ciągu dnia. | Funkcja SQL `occupancy_at(ts)` (ostatnie `to_location` każdego pacjenta przed `ts`) vs bieżące; podwójne słupki. |
| M26 | **Widok QR/NFC analytics** | Ile identyfikacji przez NFC, a ile przez QR. | Tabela `scan_events(method, result, created_at, user_id)` zapisywana przez RPC `log_scan` (tylko log, nie zmienia pacjenta). |
| M27 | **Lista pacjentów przypięta do mapy** | Klikasz pacjenta z listy i mapa automatycznie pokazuje jego lokalizację. | Layout split (tablet) lub lista w sheecie nad mapą (telefon); wybór → kamera + pin + ścieżka. |
| M28 | **Wersja „glass / premium” dla najważniejszych kart** | Delikatny nowoczesny styl dla dashboardu, nadal profesjonalny. | Patrz 7.9. |
| M29 | **Timeline pacjenta + lokalizacja na mapie** | Oś czasu w profilu zsynchronizowana z mapą: tap zdarzenia → mapa pokazuje ten oddział i fragment ścieżki. | Wspólny provider `selectedHistoryEvent`. |
| M30 | **Dashboard z wykresami i realtime** | KPI, wykresy oddziałów, feed — wszystko aktualizowane na żywo. | `fl_chart` + providery realtime. |
| M31 | **Tryb demonstracyjny na 2 urządzeniach** | Gotowe scenariusze dla transferów, sync, konfliktów na dwóch telefonach. | Patrz 9.16 + sekcja 16. |

### 8.2 SQL pod analitykę

```sql
-- 0005_analytics.sql
create view dept_stays as
select h.patient_id, h.to_location as location_id, h.created_at as entered_at,
       lead(h.created_at) over (partition by h.patient_id order by h.created_at) as left_at
from location_history h;

create view dept_stats as
select l.id, l.display_name, l.floor, l.beds,
  (select count(*) from patients p where p.current_location = l.id and p.status <> 'discharged') as patients_now,
  (select avg(coalesce(s.left_at, now()) - s.entered_at) from dept_stays s where s.location_id = l.id) as avg_stay,
  (select max(created_at) from location_history h where h.to_location = l.id) as last_transfer_in,
  (select count(*) from location_history h where h.to_location = l.id
          and h.created_at > now() - interval '2 hours') as inflow_2h
from locations l;

create view transfer_flows as
select from_location, to_location, count(*) as n
from location_history where from_location is not null
group by 1,2;

create view peak_hours as
select extract(hour from created_at at time zone 'Europe/Warsaw')::int as hour, count(*) as n
from location_history where from_location is not null group by 1;

create function occupancy_at(ts timestamptz)
returns table(location_id text, n bigint) language sql stable as $$
  select last_loc, count(*) from (
    select distinct on (patient_id) patient_id, to_location as last_loc
    from location_history where created_at <= ts
    order by patient_id, created_at desc) t
  group by last_loc $$;
-- widoki dziedziczą RLS tabel bazowych tylko z security_invoker:
alter view dept_stays set (security_invoker = on);
alter view dept_stats set (security_invoker = on);
alter view transfer_flows set (security_invoker = on);
alter view peak_hours set (security_invoker = on);
```

---

## 9. Funkcjonalności dodatkowe i rozszerzenia (kompletnie, z Twojej listy)

| # | Rozszerzenie | Opis (Twoje) | Jak zrobić, żeby nie rozwaliło core |
|---|---|---|---|
| 9.1 | **Dashboard szpitala** | Liczba pacjentów na poszczególnych oddziałach, statystyki przyjęć i wypisów oraz podsumowanie aktualnego obłożenia. | Tylko odczyty (`dept_stats`), zero nowych ścieżek zapisu. Tanie i bezpieczne — robić pierwsze. |
| 9.2 | **Notatki medyczne** | Dodawanie notatek do pacjenta z informacją o autorze, dacie utworzenia i odpowiednimi uprawnieniami. | Tabela `clinical_notes(note_id, patient_id, text, created_at default now(), created_by)`; RPC `add_note` (Nurse i Doctor), brak edycji/usuwania (append-only, jak historia). Tekst fikcyjny. |
| 9.3 | **Panel administratora** | Zarządzanie kontami personelu, rolami i dostępem do systemu. | Edge Function `admin-set-role` z service role, sprawdza czy wywołujący ma `role='admin'`. Admin nie może zmienić **własnej** roli. |
| 9.4 | **Programowanie tagów NFC** | Przypisywanie i zapisywanie identyfikatorów pacjentów bezpośrednio z aplikacji. | `Ndef.write(NdefMessage([NdefRecord.createText(code)]))`; weryfikacja odczytem po zapisie; **nie blokować tagów** (lock jest nieodwracalny). |
| 9.5 | **Obsługa dodatkowych formatów kodów kreskowych** | Identyfikacja pacjentów innymi standardami kodów. | `mobile_scanner` formaty: Code128, DataMatrix, PDF417, Aztec; ten sam parser identyfikatora. |
| 9.6 | **Pełny tryb offline z późniejszą synchronizacją** | Edycja danych i rejestrowanie transferów bez internetu, lokalny zapis operacji, synchronizacja po odzyskaniu połączenia, z wykrywaniem i rozwiązywaniem konfliktów. | Sekcja 6.2. Flaga, domyślnie OFF. Najbardziej ryzykowne rozszerzenie — robić ostatnie. |
| 9.7 | **Interaktywna mapa szpitala** | Schemat pięter i oddziałów z liczbą pacjentów oraz ich ostatnio zarejestrowanymi lokalizacjami. | Sekcja 8. |
| 9.8 | **Timeline pacjenta** | Oś czasu: przyjęcie, zmiany statusu i wszystkie transfery. | Merge `location_history` + `status_history` + przyjęcie, sort po czasie serwera. |
| 9.9 | **Powiadomienia w aplikacji** | Nowe transfery, przyjęcia, wypisy, zmiany statusu — dostosowane do roli. | Z realtime: Nurse widzi „Ready for Discharge” (do organizacji wypisu), Doctor widzi transfery na swój oddział; centrum powiadomień + toast. Push (FCM/APNs) poza zakresem. |
| 9.10 | **Skaner z szybkimi akcjami** | Po skanie natychmiastowy dostęp do danych, historii i dozwolonych operacji. | Bottom sheet z M20; akcje filtrowane rolą (i tak backend pilnuje). |
| 9.11 | **Transfery oczekujące na akceptację** | Przekazanie pacjenta z potwierdzeniem odbioru przez personel oddziału docelowego. | Tabela `transfer_requests(id, patient_id, from, to, requested_by, state pending/accepted/rejected/cancelled, …)`; RPC `request_transfer`, `accept_transfer` (Nurse z `home_location = to`). **Zmiana lokalizacji dopiero przy akceptacji, tą samą transakcją co w core.** Tryb za flagą — core działa jak w specyfikacji. |
| 9.12 | **Zaawansowane wyszukiwanie i filtrowanie** | Wiek, data przyjęcia, oddział, status, czas ostatniej aktualizacji. | Sheet filtrów (zakres wieku slider, date range, multi-select), zapytanie PostgREST z filtrami + lokalnie w cache. |
| 9.13 | **Generowanie kart i identyfikatorów pacjentów** | Automatyczne tworzenie kart pacjentów i kodów QR gotowych do wydrukowania. | Pakiet `pdf` + `printing` + `qr_flutter`; karta może mieć nadrukowane fikcyjne imię, ale **QR zawiera wyłącznie identyfikator**. |
| 9.14 | **Analityka przepływu pacjentów** | Średni czas pobytu na oddziałach, liczba transferów, obciążenie jednostek, przepływ w czasie. | Widoki z 8.2. |
| 9.15 | **Rejestr zmian statusów** | Kto, kiedy i na jaki status zmienił stan pacjenta, z opcjonalnym uzasadnieniem. | `status_history` (już w schemacie core) + ekran listy. |
| 9.16 | **Tryb demonstracyjny** | Gotowe scenariusze: transfery, synchronizacja realtime, konflikty, dwa urządzenia. | Osobny projekt Supabase „demo”; ekran „Showcase” (admin) z przyciskami scenariuszy; scenariusz to sekwencja wywołań **tych samych RPC** na koncie demo-nurse/demo-doctor (np. co 3 s); „Reset demo” przez Edge Function z service role tylko w projekcie demo. Scenariusz „konflikt” odpala dwa transfery równolegle z tą samą `expected_version`. |

---

## 10. Ekrany aplikacji — lista i wireframe'y

| Ekran | Zawartość | Rola |
|---|---|---|
| Logowanie | Email, hasło, „SIMULATION ONLY” | wszyscy |
| Dashboard | Nagłówek (imię, rola, zmiana), KPI ×4 ze sparkline, wykres oddziałów, feed, szybkie akcje, karty oddziałów, wejście do mapy | wszyscy |
| Pacjenci | Sticky search, chipy filtrów, karty, swipe (bezpieczne skróty: „Profil”, „Pokaż na mapie”) | wszyscy |
| Profil pacjenta | Header, status chip, lokalizacja + czas, mini-mapa, timeline, notatki, akcje roli | wszyscy |
| Skanuj — NFC | Pierścienie, puls, komunikaty, przełącznik na QR | wszyscy |
| Skanuj — QR | Narożniki, linia skanu, latarka, obsługa uprawnień | wszyscy |
| Quick summary (sheet) | Najważniejsze dane + akcje | wszyscy |
| Transfer (sheet + potwierdzenie) | Wyszukiwarka oddziałów, A → B, przycisk z loaderem, checkmark | Nurse |
| Konflikt | Co się zmieniło, kto, kiedy, „Odśwież” | Nurse/Doctor |
| Zmiana statusu (sheet) | 4 statusy z ikonami, opcjonalny powód | Doctor |
| Historia | Globalny feed, filtr po oddziale, timeline dnia | wszyscy |
| Mapa | 2D/3D, piętra, heatmapa, panel oddziału, lista przypięta | wszyscy |
| Analityka | Sankey, godziny szczytu, teraz vs rano, NFC/QR, wąskie gardła, średni pobyt | wszyscy |
| Ward monitor | Widok monitora oddziału (landscape) | wszyscy |
| Powiadomienia | Centrum powiadomień | wszyscy |
| Kolejka sync | Operacje oczekujące / konflikty (tryb rozszerzony) | wszyscy |
| Admin | Konta, role, programowanie tagów, karty do druku, tryb demo | Admin |
| Profil użytkownika | Dane, rola, zmiana, wylogowanie, ustawienia animacji | wszyscy |

```
┌──────────── DASHBOARD ────────────┐   ┌────────── SKANER NFC ─────────────┐
│ Dzień dobry, Anna                 │   │ ←                    [QR ⇄]       │
│ Pielęgniarka · Zmiana 7–19   ● on │   │                                    │
│ ┌───────┐┌───────┐┌───────┐┌─────┐│   │        (   (   ( ◉ )   )   )       │
│ │ 128 ▁▃││  54 ▃▅││  17 ▅▂││ 42 ▂│   │      pierścienie + puls            │
│ │wszyscy││leczeni││wypis  ││tr.  ││   │                                    │
│ └───────┘└───────┘└───────┘└─────┘│   │   Przyłóż telefon do opaski       │
│ Oddziały  SOR ████████░░ 82%      │   │   pacjenta                         │
│           RAD █████░░░░░ 50%      │   │                                    │
│           INT ███████░░░ 71%      │   │   Skan tylko otwiera rekord —     │
│ Ostatnie ruchy                    │   │   nie zmienia lokalizacji.        │
│ (AN) P104 SOR → Radiologia  2 min │   │                                    │
│ (MK) P077 status → Ready     5 min│   │         [ Anuluj ]                 │
│ [NFC] [QR] [Szukaj]  [Mapa 3D →]  │   │                                    │
├───────────────────────────────────┤   ├────────────────────────────────────┤
│ ⌂    👥    ( ◎ )    ⏱    ☺        │   │ ⌂    👥    ( ◎ )    ⏱    ☺         │
└───────────────────────────────────┘   └────────────────────────────────────┘

┌──────── QUICK SUMMARY ────────────┐   ┌──────── POTWIERDZENIE ─────────────┐
│ ▔▔▔                               │   │ Przeniesienie pacjenta             │
│ (JK) Jan Kowalski     HPT-7K3M9QX2│   │                                    │
│ 54 l. · Zapalenie płuc            │   │  [SOR]  ──────●──────▶ [Radiologia]│
│ ● In Treatment                    │   │  parter                 parter     │
│ ⌖ SOR · parter · 14 min temu      │   │                                    │
│                                   │   │  Poprzednia: SOR (od 09:12)        │
│ [Profil] [Historia] [Przenieś →]  │   │  Nowa:       Radiologia            │
└───────────────────────────────────┘   │                                    │
                                        │  [   ◌  Zapisywanie…   ] (lock)    │
┌──────── KONFLIKT ─────────────────┐   │          ↓ po 200 OK               │
│ ⚠ Pacjent został już przeniesiony │   │            ✓  Przeniesiono         │
│ A. Nowak · 10:41 · → Laboratorium │   └────────────────────────────────────┘
│ Twoja zmiana NIE została zapisana │
│ [ Odśwież i wybierz ponownie ]    │
└───────────────────────────────────┘
```

---

## 11. Plan 8 tygodni (zgodny ze specyfikacją + wpięte rozszerzenia)

**Role w zespole 4-osobowym** (przy 3 osobach: C i D łączą się, a P2 tnie się w połowie):

| Osoba | Odpowiedzialność główna | Odpowiedzialność wtórna |
|---|---|---|
| **A — Mobile/Hardware** | NFC, QR, uprawnienia urządzeń, iOS signing/entitlements, build na fizycznych telefonach | Programowanie tagów, dodatkowe kody, karty do druku |
| **B — Backend** | Schemat, RLS, RPC, realtime, seed, testy pgTAP, test współbieżności | Widoki analityczne, Edge Functions (admin, demo) |
| **C — UI/UX** | Design system, dashboard, lista, profil, transfer, animacje | Mapa 2D/3D, sankey, timeline dnia, ward monitor |
| **D — Data/Reliability/QA** | Riverpod, repozytoria, cache Drift, offline, realtime w aplikacji, konflikty | Testy na urządzeniach, dokumentacja, raport, kolejka offline |

| Tydzień | Cel ze specyfikacji | Zadania | Kryterium „done” |
|---|---|---|---|
| **1** Setup i hardware | Git, app, backend; app na fizycznym iOS i Androidzie; odczyt NDEF na obu; podział ról | A: projekt Flutter, signing iOS, **NFC capability i konto Apple**, odczyt NDEF; B: projekt Supabase, migracje 0001, seed oddziałów; C: tokeny design systemu, szkielet nawigacji; D: Riverpod, router, CI (analyze + test) | Ten sam tag czytany na iPhonie i Androidzie, wynik wyświetlony na ekranie |
| **2** Auth i identyfikacja | Logowanie, początkowe reguły; NFC i QR otwierają ten sam rekord; nieznane ID, anulowanie | A: QR, parser ID, fallback NFC→QR, uprawnienia kamery; B: Auth, profiles, RLS read, konta testowe; C: login, ekran skanera (pierścienie, QR overlay); D: PatientRepo, provider sesji | NFC i QR → ten sam pacjent; nieznany/zły kod/anulowanie obsłużone |
| **3** Szczegóły i uprawnienia | Profil pacjenta, macierz uprawnień; backend odrzuca nieautoryzowane | B: RPC `transfer_patient`, `set_patient_status`, revoke grantów, testy pgTAP; C: profil, quick summary sheet, status chip; D: mapowanie błędów PTxxx; A: haptics, glow po odczycie | **curl z JWT pielęgniarki na `set_patient_status` → PT403**, PATCH na `patients` → permission denied |
| **4** Transfery i historia | Wybór celu, potwierdzenie, atomowy zapis, historia | C: sheet oddziałów + wyszukiwarka, potwierdzenie A→B, checkmark; D: `client_request_id`, blokada przycisku, timeline historii; B: `status_history`, triggery append-only | **KAMIEŃ MILOWY: pełny flow skan → transfer → historia na obu telefonach** |
| **5** Lista i synchronizacja | Lista, wyszukiwanie, filtry; zmiana na 2. urządzeniu bez odświeżania | D: realtime + refetch po reconnect; C: lista, chipy, flash zmian, live feed, dashboard KPI (P1); B: indeksy, `dept_stats` | iOS ↔ Android: transfer pojawia się w < 2 s |
| **6** Niezawodność i offline | Cache, offline indicator, blokada zapisów offline; błędy, powtórne kliknięcia, konflikty | D: Drift cache, baner, etykiety „z cache”, timeout→„Sprawdź”; B: `tools/concurrency_test`; C: ekran konfliktu, skeletony, empty states | Test 7 i 8 ze specyfikacji zielone |
| **7** Testy cross-platform | Testy akceptacyjne iOS/Android, poprawki, szkic raportu; **rozszerzenia dopiero po zielonym core** | Wszyscy: przejście 8 testów akceptacyjnych na urządzeniach; po zaliczeniu: C — mapa 2D/3D + heatmapa + ścieżki, A — programowanie tagów + karty, B — analityka + demo-reset, D — notatki + powiadomienia | Tabela wyników w `TESTING.md`; core zamrożony (tag `v1.0-core`) |
| **8** Walidacja i demo | Czysta instalacja z dokumentacji; oddanie; demo; wkład | Ktoś spoza B stawia backend z README; próba generalna demo ×2; próbne „przepytanie” każdego; P2/P3 tylko jeśli stabilne | Wszystko oddane, każdy umie wyjaśnić flow i SQL |

**Brutalna uwaga o harmonogramie:** C może prototypować mapę 2D/3D na fikcyjnych danych od tygodnia 4–5 na osobnej gałęzi, ale **merge do `main` dopiero po tagu `v1.0-core`**. Jeśli w tygodniu 6 core nie przechodzi testów 7–8 — C rzuca mapę i pomaga D. Bez dyskusji.

---

## 12. Testy akceptacyjne (z PDF) i jak je zaliczyć

| # | Test | Jak pokazać | Dowód |
|---|---|---|---|
| 1 | Logowanie i otwarcie tego samego pacjenta przez NFC i QR | Login nurse1 → skan opaski NFC → wróć → skan QR z kartki → ten sam `HPT-…` i ten sam rekord | Nagranie ekranu |
| 2 | Transfer jako Nurse i zmiana na drugim urządzeniu | iPhone (nurse1) przenosi pacjenta; Android (doctor1) widzi flash na liście, feed, mapę | Nagranie obu telefonów |
| 3 | Wpis historii: poprzednia lokalizacja, cel, czas, aktor | Profil → timeline → wpis z `from`, `to`, czasem serwera, inicjałami | Zrzut + zapytanie SQL |
| 4 | Zmiana statusu jako Doctor | Android doctor1 → status Ready for Discharge | Wpis w `status_history` |
| 5 | Backend odrzuca nieautoryzowaną zmianę, także z pominięciem UI | `curl …/rest/v1/rpc/set_patient_status` z JWT pielęgniarki → PT403; `PATCH /rest/v1/patients` → permission denied; bez tokenu → 401 | Terminal na projektorze |
| 6 | Nieznany ID, anulowane skanowanie, brak NFC lub odmowa kamery | Tag z `HPT-ZZZZZZZZ` → „Nieznany pacjent”; anulowanie arkusza iOS; odmowa kamery → „Otwórz ustawienia”; telefon bez NFC/NFC wyłączone → fallback QR | Nagranie |
| 7 | Utrata sieci: offline, cache, blokada zapisów | Tryb samolotowy → baner, „Dane z cache · 10:42”, przycisk „Przenieś” wyłączony; pacjent niepobrany → komunikat | Nagranie |
| 8 | Powtórne wysłanie i równoległe transfery bez duplikatów i niespójności | Szybki potrójny tap → 1 zdarzenie; dwa telefony nurse1/nurse2 z tym samym pacjentem zatwierdzają jednocześnie → jeden ✓, drugi ekran konfliktu; `tools/concurrency_test` 50× → zawsze 1 sukces | SQL: `select count(*) …` + log skryptu |

### 12.1 Testy automatyczne
- **pgTAP (`supabase test db`)**: anon nie czyta pacjentów; nurse nie zmienia statusu; doctor nie przenosi; nikt nie robi UPDATE/DELETE historii; nieaktualna wersja → PT409; ten sam `client_request_id` → jedno zdarzenie; zły oddział → PT422; transfer zmienia `version`, `location_updated_at` i tworzy dokładnie 1 wiersz historii.
- **Dart unit**: parser identyfikatora (poprawne, złe prefiksy, małe litery, znaki I/L/O/U, puste, za długie), mapowanie błędów, logika heatmapy (progi), agregacja sankey.
- **Widget**: stany loading/empty/error, przycisk transferu zablokowany offline i w trakcie zapisu, checkmark dopiero po sukcesie (mock repo).
- **integration_test na urządzeniach**: login → wyszukaj → transfer → historia.
- **Skrypt współbieżności**: N równoległych `transfer_patient` z tą samą `expected_version` → dokładnie 1 sukces, N−1 × PT409, liczba wierszy historii +1.

---

## 13. Scenariusz demonstracji końcowej (DEMO_SCRIPT.md) — ~12 minut

1. **(1 min)** Architektura na jednym slajdzie + zdanie o fikcyjnych danych.
2. **(2 min)** Test 1: login nurse1 na iPhonie → NFC → QR → ten sam pacjent. Szybkie podsumowanie w bottom sheecie.
3. **(2 min)** Test 2+3: transfer SOR → Radiologia, checkmark po potwierdzeniu; Android (doctor1) obok: flash na liście, wpis w feedzie, kropka przesuwa się na mapie; timeline z aktorem i czasem serwera.
4. **(1 min)** Test 4: doctor1 zmienia status na Ready for Discharge; iPhone widzi zmianę.
5. **(1,5 min)** Test 5: terminal — curl jako nurse na `set_patient_status` → PT403; PATCH bez RPC → denied; bez tokenu → 401.
6. **(1,5 min)** Test 6: nieznany tag, anulowanie, odmowa kamery, telefon/tryb bez NFC.
7. **(1 min)** Test 7: tryb samolotowy, baner, cache, zablokowany transfer.
8. **(1 min)** Test 8: potrójny tap → 1 zdarzenie; dwa telefony jednocześnie → konflikt; wynik skryptu współbieżności.
9. **(1 min, bonus)** Showcase: mapa 3D z heatmapą, animowana ścieżka pacjenta, sankey, timeline dnia — tryb demo odtwarza transfery na żywo na obu telefonach.

> Kolejność jest celowa: najpierw wszystko, co jest punktowane, na końcu „wow”. Jeśli czas się skończy, utniecie bonus, a nie testy.

---

## 14. Dane testowe, tagi i QR

- `supabase/seed.sql`: 12 oddziałów na 3 piętrach, 30 fikcyjnych pacjentów (imiona z generatora, schorzenia ogólne: „zapalenie płuc”, „złamanie kości promieniowej”, „obserwacja po urazie głowy”…), zdarzenia przyjęcia, kilka historycznych transferów, żeby timeline i analityka nie były puste.
- Konta: `nurse1`, `nurse2`, `doctor1`, `doctor2`, `admin` (opcjonalny) — tworzone skryptem przez Admin API; hasła w lokalnym `.env`/menedżerze haseł zespołu, **nie w repo**.
- `tools/generate_tags`: generuje `tags.csv` (patient_code, imię dla kontroli) i `qr_sheet.pdf` (QR + kod tekstowy + miejsce na naklejkę NFC). Tagi kodowane aplikacją (rozszerzenie 9.4) lub zewnętrznym narzędziem (np. NFC Tools) jako NDEF Text.
- Do oddania: fizyczne naklejki NTAG213 na symulowanych opaskach/teczkach + pasujące wydrukowane QR, każdy podpisany kodem.
- Specjalne tagi testowe: nieznany ID (`HPT-ZZZZZZZZ`), zły format (`HELLO`), pusty tag, tag z URL — do testu 6.

---

## 15. Priorytety (wszystko zostaje, zmienia się tylko kolejność)

| Priorytet | Co | Kiedy |
|---|---|---|
| **P0 — bez tego oblewacie** | Cała sekcja 2 (wymagania 1–45 + 2.1), RLS/RPC, idempotencja, konflikty, cache + offline indicator, 8 testów akceptacyjnych, dokumentacja | Tyg. 1–7 |
| **P1 — tanie, duży efekt** | Dashboard z KPI, count-up, sparkline i realtime (9.1, M30), live activity feed (M11), quick summary bottom sheet (M20, 9.10), timeline pacjenta (9.8), rejestr zmian statusów (9.15), avatary/inicjały (M19), animacje premium z 7.9, mapa 2D z heatmapą i kolorowymi stanami (M2, M5, M13), mini-mapa (M8), „gdzie jest pacjent” (M3) | Tyg. 5–7 (UI w trakcie core, bo to i tak ekrany core) |
| **P2 — wow na prezentację** | Mapa 3D (M1) + przełącznik 2D/3D (M7) + filtr pięter (M22), animowana ścieżka (M4), animacje przejść (M23), panel oddziału (M6), interaktywne karty oddziałów (M14), lista przypięta do mapy (M27), timeline + mapa (M29), dashboard obłożenia (M9), sankey (M10, 9.14), timeline dnia (M16), godziny szczytu (M17), teraz vs rano (M25), wąskie gardła (M24), NFC/QR analytics (M26), historia oddziału (M15), ward monitor (M21), tryb demo (M18, M31, 9.16), glass (M28), notatki (9.2), powiadomienia (9.9), zaawansowane filtry (9.12), admin (9.3), programowanie tagów (9.4), dodatkowe kody (9.5), karty do druku (9.13) | Tyg. 7–8, po tagu `v1.0-core` |
| **P3 — ryzykowne, na końcu, za flagą** | Pełny offline z synchronizacją (9.6, 6.2), transfery z akceptacją (9.11) | Tylko jeśli P2 stabilne |

---

## 16. Ryzyka i jak im zapobiec

| Ryzyko | Prawdopodobieństwo | Skutek | Zapobieganie |
|---|---|---|---|
| NFC na iOS nie działa (konto, entitlement, Info.plist) | wysokie | blokada testu 1 | Tydzień 1: `NFCReaderUsageDescription`, capability, płatne konto; testowy odczyt |
| Ktoś zostawia zapis przez tabelę „bo szybciej” | średnie | oblany test 5 | Revoke grantów w migracji + test pgTAP w CI |
| Realtime gubi zdarzenia po uśpieniu telefonu | wysokie | rozjechany drugi telefon na demo | Refetch na `resumed` i reconnect; wskaźnik połączenia |
| Mapa 3D zjada tygodnie | wysokie | brak czasu na core | 2.5D na `Matrix4`, osobna gałąź, merge po `v1.0-core` |
| Wydajność animacji na starszym Androidzie | średnie | lagi na demo | `RepaintBoundary`, max 1–2 `BackdropFilter`, profil w `--profile` |
| Klucze Supabase w repo | średnie | dyskwalifikacja/wstyd | `.env` + `--dart-define`, `service_role` nigdy w aplikacji, secret scanning na GitHubie |
| Jedna osoba rozumie backend | wysokie | słabe oceny indywidualne | Rotacja review, każdy pisze 1 RPC/test, próbne przepytanie |
| Niespójny czas (strefy) | średnie | złe godziny w historii/wykresach | Zawsze `timestamptz`, wyświetlanie w `Europe/Warsaw` |
| Pełny offline łamie zasady core | wysokie | konflikt ze specyfikacją | Flaga OFF na demo core, jawna kolejka |

---

## 17. Macierz urządzeń (TESTING.md — do uzupełnienia realnymi danymi)

| Urządzenie | OS | NFC | QR | Realtime | Offline | Konflikty | Uwagi |
|---|---|---|---|---|---|---|---|
| iPhone (model ≥ XS) | iOS __ | ☐ | ☐ | ☐ | ☐ | ☐ | systemowy arkusz NFC |
| Android z NFC | Android __ | ☐ | ☐ | ☐ | ☐ | ☐ | reader mode |
| Android bez NFC / NFC wyłączone | Android __ | fallback ☐ | ☐ | — | — | — | test 6 |

Znane ograniczenia (wpisać uczciwie): brak pozycjonowania automatycznego (system rejestruje tylko potwierdzone ruchy), Realtime bez replay, wspólna wersja status/lokalizacja = możliwe fałszywe konflikty, iOS bez custom UI w trakcie sesji NFC.

---

## 18. Dokumentacja do oddania (deliverables)

1. **Kod źródłowy** we wspólnym repo GitHub (historia commitów wszystkich członków).
2. **Backend:** migracje, RLS, RPC, seed, instrukcja „od zera do działającego projektu” (`docs/BACKEND.md`), bez prywatnych kluczy.
3. **Raport:** architektura, format identyfikatora, uprawnienia, współbieżność i offline, wyzwania, wkład indywidualny (`docs/CONTRIBUTIONS.md` + linki do PR).
4. **Wyniki testów:** urządzenia, wersje OS, znane ograniczenia (`docs/TESTING.md`).
5. **Dane syntetyczne, instrukcja kont testowych, naklejki NTAG213 i pasujące QR.**
6. **Demo na żywo**, w którym każdy umie wyjaśnić system.

---

## 19. Definicja „gotowe” dla całego projektu

- [ ] 45 wymagań obowiązkowych + szczegóły z 2.1 odhaczone
- [ ] 8 testów akceptacyjnych zielonych na iOS **i** Androidzie, nagrane
- [ ] pgTAP + skrypt współbieżności w CI
- [ ] Czysta instalacja z README wykonana przez osobę spoza backendu
- [ ] Tag `v1.0-core`, potem rozszerzenia P1 → P2 → P3
- [ ] Każdy członek zespołu przeszedł próbne przepytanie z całego flow, RLS i RPC
- [ ] Mapa 2D/3D, heatmapa, animowana ścieżka, live feed, dashboard realtime, tryb demo na 2 urządzeniach i timeline pacjenta z lokalizacją na mapie działają na prawdziwych danych z Supabase, nie na mockach
