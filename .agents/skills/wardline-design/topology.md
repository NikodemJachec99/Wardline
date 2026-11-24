# Topologia: ekran → artboard → spec → kod

Szukasz czegoś? Znajdź wiersz, otwórz artboard (`design/canvas/<Plik>.dc.html` przez `python3 -m http.server`), przeczytaj spec, koduj w podanej ścieżce. Ścieżki w `app/lib/` oznaczone *(plan)* jeszcze nie istnieją: tworzysz je dokładnie tam.

## Repo w skrócie

```
design/
  Wardline_Design_System-project.zip   oryginalny eksport (nie edytuj)
  canvas/                              39 artboardów *.dc.html + canvas.json + _runtime/ (podgląd lokalny)
  handoff/                             spec do implementacji (czytasz to)
    CLAUDE_CODE_BRIEF.md               start, kolejność PR, DoD, zakazy
    README.md                          decyzje design vs PLAN
    tokens.json                        wartości tokenów
    flutter/wl_tokens.dart             kopia referencyjna tokenów (kod jest w app/)
    components.md  screens.md  flows.md  motion.md  platform-and-a11y.md  copy.md
    sample-data.json                   mocki + geometria mapy
app/lib/
  app/            router.dart (go_router, StatefulShellRoute, 5 zakładek), theme.dart (buildTheme), shell_scaffold.dart
  core/theme/     wl_tokens.dart  ← jedyne źródło kolorów, odstępów, czasów
  core/widgets/wl/  Wl* widgety *(plan)*
  data/           repozytoria, DTO, Drift
  features/<feature>/presentation/  ekrany
docs/PLAN.md      produkt + backend (RPC, RLS, błędy PTxxx, offline)
```

## Design system (strona *Design system* na canvasie)

| Temat | Artboard | Spec | Kod |
|---|---|---|---|
| Marka, ikona app, zasady produktu | `Main` | `CLAUDE_CODE_BRIEF.md` | `app/assets/` |
| Kolory, statusy, obłożenie, role | `Colour` | `tokens.json` → `color` (w tym `status.*`, `occupancy.*`, `role.*`) | `core/theme/wl_tokens.dart` (`WlColors`, `WlStatusStyle`, `WlOccupancyStyle`, `WlRoleStyle`) |
| Typografia, ikony | `Type` | `tokens.json` → `type` | `WlType` / `tokens.typography` |
| Odstępy, promienie, cienie, ruch | `Layout` | `tokens.json`, `motion.md` | `WlSpace`, `WlRadius`, `WlElevation`, `WlMotionTokens`, `WlMotion` |
| Przyciski, pola, chipy, przełączniki | `Controls` | `components.md` → WlButton, WlFilterChips, WlSearchBar | `core/widgets/wl/` *(plan)* |
| Karta pacjenta, status chip, avatar, timeline | `Patient` | `components.md` → WlPatientCard, WlStatusChip, WlInitialsAvatar, WlTimelineItem | `core/widgets/wl/` *(plan)* |
| KPI, feed, obłożenie, mini mapa | `Dashboard` | `components.md` → WlKpiCard, WlActivityFeedItem, WlDeptOccupancyBar, WlMiniMap, WlDepartmentCard | `core/widgets/wl/` *(plan)* |
| Offline, cache, połączenie, toast, empty, error, skeleton | `States` | `components.md`, `copy.md` → Global | `core/widgets/wl/` *(plan)* |
| Bottom nav, sheety, przejścia | `Navigation` | `components.md` → WlBottomNav, WlBottomSheet; `motion.md` | `app/shell_scaffold.dart`, `core/widgets/wl/` |

## Ekrany

| Ekran | Route | Artboardy | Spec | Kod |
|---|---|---|---|---|
| Logowanie | `/login` | `Login` | `screens.md`, artboard `Login` (teksty) | `features/auth/presentation/` *(plan)* |
| Dashboard (układ B) | `/dashboard` | `DashB` (wybrany), `DashDoctor`, `DashLoading`; `DashA` to odrzucona alternatywa, nie implementuj | `screens.md`, `motion.md` (stagger, count-up) | `features/dashboard/presentation/dashboard_screen.dart` |
| Lista pacjentów + filtry | `/patients` | `PatientsList` | `screens.md`, `flows.md` 3, 4, 6 | `features/patients/presentation/patients_screen.dart` |
| Profil pacjenta | `/patients/:id` | `Profile` (Nurse), `ProfileDoctor`, `ProfileOffline` | `screens.md`, `components.md` → WlTimelineItem, WlMiniMap | `features/patients/presentation/patient_profile_screen.dart` *(plan)* |
| Skan NFC / QR | `/scan` (modal nad shellem) | `ScanNfc`, `ScanIos`, `ScanSuccess`, `ScanQr`, `ScanEdge` | `screens.md`, `platform-and-a11y.md`, `copy.md` → Scan, `flows.md` 1 | `features/scan/presentation/scan_screen.dart` |
| Transfer (wybór, potwierdzenie, sukces, konflikt, timeout, offline) | `/patients/:id/transfer`, `/patients/:id/transfer/confirm` | `TransferFlow` (kroki 1→7) | `screens.md`, `flows.md` 1, 2, `components.md` → WlTransferPath | `features/transfer/presentation/` *(plan)* |
| Zmiana statusu | sheet `/patients/:id/status` | `StatusFlow` | `screens.md`, `flows.md` 3 | `features/status/presentation/` *(plan)* |
| Historia, historia oddziału, oś dnia | `/history`, `/history/dept/:id`, `/history/timeline` | `HistoryFlow` | `screens.md` | `features/history/presentation/` |
| Powiadomienia, ustawienia (Reduce motion) | `/notifications`, `/profile` | `Account` | `screens.md`, `copy.md` | `features/notifications/` *(plan)*, `features/profile/presentation/` |
| Mapa szpitala | `/map` | `MapLive`, `MapStates` | `screens.md`, `flows.md` 5, `sample-data.json` → `departments[].map` | `features/map/` *(plan)* |
| Android + duży tekst | wszystkie | `Platform` | `platform-and-a11y.md` | wszystkie ekrany |

## Opcjonalne (po rdzeniu P0)

| Funkcja | Route | Artboard | Uwaga |
|---|---|---|---|
| Kolejka synchronizacji | `/profile/sync` | `OfflineMode` | Flaga P3, domyślnie OFF |
| Oczekujące transfery | n/d | `OfflineMode` | Dodaje drugie potwierdzenie, którego model nie ma. Bez uzasadnienia nie robić |
| Panel admina | `/admin/*` | `Admin` | Role przez Edge Function (service role po stronie serwera) |
| Analityka (tablet) | `/analytics` | `Analytics` | ≥ 900dp, widoki SQL z PLAN §8.2 |
| Monitor oddziału (tablet) | `/monitor/:dept` | `WardMonitor` | tylko odczyt |
| Tryb demo | `/admin/demo` | `DemoMode` | tylko dane symulacyjne |

## Prototyp i handoff

| Co | Artboard |
|---|---|
| Klikalny prototyp, flow 1–5 | `Proto` |
| Dwa urządzenia, realtime | `ProtoSync` |
| Spec animacji (to samo co `motion.md`) | `MotionSpec` |
| Tabele handoffu (to samo co `design/handoff/*.md`) | `Handoff` |

## Teksty: gdzie szukać

| Sytuacja | Sekcja w `copy.md` |
|---|---|
| Offline, cache, połączenie, nota "Simulation" na logowaniu | Global |
| Skan, błędne tagi, brak NFC, kamera | Scan |
| Transfer, konflikt, timeout | Transfer (Nurse) |
| Status, wypis | Status (Doctor) |
| Listy, puste stany, błędy ładowania | Lists, empty and errors |

Teksty ekranu logowania i reszty, których nie ma w `copy.md`, bierzesz z artboardu (`Login`, `Account`, `HistoryFlow`) i **dopisujesz do `copy.md`** w tym samym PR.
