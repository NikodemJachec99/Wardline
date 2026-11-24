---
name: wardline-design
description: Obowiązkowy design system Wardline. Użyj ZAWSZE przed każdą pracą w tym repo, która dotyka UI, UX, tekstów w aplikacji, kolorów, ikon, animacji, nawigacji, ekranów, widgetów, stanów (loading/empty/error/offline), dostępności albo flow (skan, transfer, zmiana statusu, mapa). Także przy review PR z UI i przy planowaniu issue. Mówi, gdzie co leży (canvas, handoff, tokeny, specy, kod), jak to czytać i czego nie wolno robić.
---

# Wardline design: obowiązkowy

Ten projekt ma **jeden** design i każdy go używa: ludzie, Claude Code, Copilot, Cursor, kto tam jeszcze. Nie wymyślasz własnych kolorów, odstępów, tekstów, ikon ani układów. Jeśli czegoś nie ma w designie, najpierw sprawdzasz, czy naprawdę nie ma (topologia niżej), potem składasz to z istniejących `Wl*` widgetów i tokenów, a na końcu dopisujesz to do specy w `design/handoff/` w tym samym PR.

> Ten skill leży w `.agents/skills/wardline-design/` (standard [Agent Skills](https://agentskills.io/specification), czytają go Codex, Copilot, Gemini CLI, Cursor). Claude Code dostaje lokalną kopię w `.claude/skills/` (hook `SessionStart` → `tools/sync-agent-skills.sh`, kopia w `.gitignore`). **Edytujesz tylko `.agents/skills/`.** Walidacja: `python3 tools/validate-agent-skills.py` (też w CI).

> SIMULATION ONLY. Wszystkie imiona, ID i liczby w designie są fikcyjne. Nie wstawiaj prawdziwych danych.

## Kolejność pracy (zawsze)

1. **Znajdź ekran / komponent** w [topology.md](topology.md): artboard na canvasie, wiersz w `screens.md` / `components.md`, docelowa ścieżka w `app/lib/`.
2. **Przeczytaj spec** w `design/handoff/` (tylko potrzebne pliki, tabela niżej).
3. **Obejrzyj artboard** (lokalnie, patrz "Jak oglądać canvas"). Dokładne kolory, odstępy i copy są w inline styles plików `design/canvas/*.dc.html`.
4. **Koduj tylko z `WlTokens`** i istniejących `Wl*` widgetów. Brakujący widget = nowy `Wl*` w `app/lib/core/widgets/wl/` zgodnie z `components.md`, nie jednorazowy `Container` w ekranie.
5. **Sprawdź** [checklist.md](checklist.md) przed PR. W PR dorzuć zrzut ekranu obok artboardu, z którego robiłeś.

## Gdzie co leży

| Potrzebujesz | Plik | Po co |
|---|---|---|
| Od czego zacząć implementację | `design/handoff/CLAUDE_CODE_BRIEF.md` | Zasady produktu, kolejność PR-ów, DoD ekranu, zakazy |
| Decyzje design vs PLAN | `design/handoff/README.md` → "Decisions" | Rozstrzygnięte konflikty (język, disabled, mapa, ID, glass) |
| Kolory, odstępy, promienie, cienie, czasy animacji, typografia | `app/lib/core/theme/wl_tokens.dart` (kod) · `design/handoff/tokens.json` (wartości) | Jedyne źródło wartości. `WlTokens.of(context)` |
| Jak wygląda i działa widget | `design/handoff/components.md` | API, warianty, stany do golden testów, semantics |
| Jaki ekran, route, stany, dane, różnice ról | `design/handoff/screens.md` | Każdy ekran: loading / empty / error / offline |
| Krok po kroku flow (kryteria akceptacji) | `design/handoff/flows.md` | 6 flow = testy integracyjne |
| Animacje | `design/handoff/motion.md` | Trigger, czas, easing, fallback reduced motion, klasa Flutter |
| iOS / Android / dostępność | `design/handoff/platform-and-a11y.md` | NFC per platforma, safe area, kontrast, 48dp, text scale 2.0 |
| Każdy tekst w UI | `design/handoff/copy.md` | Klucze l10n + angielskie teksty. Nie piszesz copy od siebie |
| Dane do mocków, mapa | `design/handoff/sample-data.json` | Oddziały z geometrią mapy, personel, pacjenci, historia |
| Wygląd 1:1 | `design/canvas/*.dc.html` (+ `canvas.json`) | Wizualne źródło prawdy, 39 artboardów |
| Oryginalny eksport | `design/Wardline_Design_System-project.zip` | Archiwum, nie edytuj |
| Backend (RPC, błędy, RLS) | `docs/PLAN.md` §2, §5, §6 | `transfer_patient`, `set_patient_status`, `PTxxx` |
| Żywy canvas (edycja designu) | https://claude.ai/artifact/W1xGQWDTSiCacKQMSiUwqu | Prywatny, dostęp przez właściciela repo |

**Hierarchia przy sprzeczności:** zasady produktu (niżej) > `design/handoff/README.md` Decisions > `design/handoff/*.md` > artboard na canvasie > `docs/PLAN.md` §7–§10 (stara wersja UI w PLAN jest zastąpiona przez design). Backend (§5, §6 schematy, RPC, RLS) zawsze z `docs/PLAN.md`.

## Jak oglądać canvas

```bash
cd design/canvas && python3 -m http.server 8080
```

Otwórz `http://localhost:8080/DashB.dc.html` (albo inny artboard). Na github.com i z dysku widać tylko surowy HTML. Klikalny prototyp: `Proto.dc.html` (flow 1–5, przycisk Play), dwa urządzenia: `ProtoSync.dc.html`.

## Zasady produktu (nie do negocjacji)

1. **Skan (NFC/QR) tylko otwiera pacjenta.** Nigdy nic nie zapisuje.
2. **Akcje ról:** Nurse transferuje (`transfer_patient`), Doctor zmienia status (`set_patient_status`), Admin nic z tych dwóch. Akcji, której rola nie może zrobić, **nie renderujesz**. Nie ma wyszarzonych przycisków za brak uprawnień.
3. **Lokalizacja i status to osobne pola**, osobne komponenty, osobne wiersze.
4. **Sukces dopiero po odpowiedzi serwera.** Przycisk: spinner + ignoruje kolejne tapnięcia. Jeden `client_request_id` na intencję, ten sam przy "Check status" po timeoucie.
5. **Offline:** czytasz z cache (Drift) z `WlCacheBadge` + `WlOfflineBanner`; każda akcja zapisu jest **zastąpiona** tekstem "Changes need a connection". Zero cichego kolejkowania.
6. **`PT409`** → ekran konfliktu (kto, skąd → dokąd, kiedy, "Refresh and choose again"). Nigdy auto-retry.
7. **Nigdy sam kolor:** status = kolor + ikona + tekst; obłożenie = kolor + % (+ "Full"/"Bottleneck"); rola = kolor obwódki + etykieta.

## Zasady wizualne

- **Tylko tokeny.** Zero `Color(0x…)`, `Colors.*`, liczb typu `16.0`, `Duration(milliseconds: …)` w ekranach. Wszystko z `WlTokens.of(context)` (`colors`, `space`, `radius`, `elevation`, `motion`, `typography`). Wyjątek: wartości wewnątrz `wl_tokens.dart`.
- **Font Inter** (bundlowany, 400–700). Cyfry tabelaryczne dla czasu, liczb, %, ID (`typography.id`, `typography.kpi`).
- **Brand teal `#0E9FA6` nigdy jako tekst** (kontrast 3.2:1). Tekst tylko w `text`, `textSecondary`, `primaryInk`, `status.fg`.
- **Glass KPI bez `BackdropFilter`**: biały 72% + 60% biała linia (`glassFill`, `glassBorder`).
- **Bez zdjęć pacjentów, emoji, neonów, ciemnego "terminal" stylu.** Pacjent = neutralny avatar z inicjałami, nigdy w kolorze statusu.
- **Nawigacja:** 5 zakładek (Dashboard, Patients, Scan, History, Profile), Scan jako podniesione 64dp kółko. **Nie dodawaj 6. zakładki** (mapa jest z karty na Dashboardzie i mini mapy w profilu).
- **Dotyk ≥ 48×48dp**, główne akcje 56dp. Każdy interaktywny element ma etykietę `Semantics`.
- **Text scale 2.0** bez overflow; powyżej 1.3 wiersze label/value się układają w pionie. Nic nie ucina imion, ID, lokalizacji.
- **Reduced motion:** `WlMotion.reduced(context)` → fallback z `motion.md`. Nic, co potwierdza zapis, nie animuje się przed odpowiedzią serwera.
- **Język UI: angielski**, teksty z `copy.md` (decyzja 1 w `design/handoff/README.md`). Kod, komentarze i dokumentacja zespołu mogą być po polsku.

## Nazwy

`Wl*` widgety i tokeny mają nazwy z canvasu i `components.md`. **Nie zmieniaj nazw.** Widgety: `WlButton`, `WlStatusChip`, `WlInitialsAvatar`, `WlPatientCard`, `WlKpiCard`, `WlDeptOccupancyBar`, `WlSearchBar`, `WlFilterChips`, `WlBottomNav`, `WlBottomSheet`, `WlTimelineItem`, `WlActivityFeedItem`, `WlTransferPath`, `WlOfflineBanner`, `WlCacheBadge`, `WlConnectionIndicator`, `WlEmptyState`, `WlErrorState`, `WlSkeleton`, `WlToast`, `WlMiniMap`, `WlDepartmentCard`. Pole typografii w `WlTokens` to `typography` (nie `type`, bo koliduje z `ThemeExtension.type`).

## Gdy design czegoś nie ma albo jest błędny

1. Sprawdź jeszcze raz: `topology.md`, `screens.md`, `copy.md`, artboard `States`, `ScanEdge`, `MapStates`.
2. Złóż rozwiązanie z istniejących tokenów i `Wl*`. Nie dodawaj nowego koloru ani rozmiaru.
3. W tym samym PR dopisz brakujący stan / tekst / komponent do właściwego pliku w `design/handoff/` i napisz w opisie PR "Rozszerza design: …".
4. Zmiana wizualna istniejącego elementu (inny kolor, nowy układ) = najpierw zmiana na canvasie, re-eksport do `design/canvas/` (patrz `design/canvas/README.md`), potem kod. Nie odwrotnie.

## Testy, które design wymaga

- Golden test per widget per stan z `components.md`.
- Każdy ekran: wszystkie stany z `screens.md` (golden albo widget test) + render przy `TextScaler.linear(2)`.
- Flow z `flows.md` jako testy integracyjne (np. flow 1: zero wywołań RPC po skanie, jedno wywołanie i jeden `client_request_id` po podwójnym tapnięciu).
- `Theme.of(context).extension<WlTokens>()` nie jest null (już jest w `app/test/core/theme/wl_tokens_test.dart`).
